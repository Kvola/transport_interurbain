# -*- coding: utf-8 -*-

from odoo import api, fields, models, _
from odoo.exceptions import ValidationError, UserError
from odoo.tools import float_compare
from datetime import datetime, timedelta
import pytz
import logging

_logger = logging.getLogger(__name__)


class TransportTrip(models.Model):
    """Voyage programmé"""
    _name = 'transport.trip'
    _description = 'Voyage programmé'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _order = 'departure_datetime desc'

    name = fields.Char(
        string='Référence',
        required=True,
        copy=False,
        readonly=True,
        default='/',
        index=True,
    )
    schedule_id = fields.Many2one(
        'transport.trip.schedule',
        string='Programme source',
        readonly=True,
        index=True,
        help="Programme de voyage ayant généré ce voyage",
    )
    transport_company_id = fields.Many2one(
        'transport.company',
        string='Compagnie',
        required=True,
        tracking=True,
        index=True,
    )
    route_id = fields.Many2one(
        'transport.route',
        string='Itinéraire',
        required=True,
        tracking=True,
        domain="[('state', '=', 'active')]",
    )
    bus_id = fields.Many2one(
        'transport.bus',
        string='Bus',
        required=True,
        tracking=True,
        domain="[('transport_company_id', '=', transport_company_id), ('state', '=', 'available')]",
    )
    driver_name = fields.Char(
        string='Conducteur',
        tracking=True,
    )
    driver_phone = fields.Char(
        string='Téléphone conducteur',
    )
    
    # Dates et heures
    departure_datetime = fields.Datetime(
        string='Date et heure de départ',
        required=True,
        tracking=True,
        index=True,
    )
    arrival_datetime = fields.Datetime(
        string='Date et heure d\'arrivée estimée',
        compute='_compute_arrival_datetime',
        store=True,
    )
    actual_departure = fields.Datetime(
        string='Départ réel',
        tracking=True,
    )
    actual_arrival = fields.Datetime(
        string='Arrivée réelle',
        tracking=True,
    )
    
    # Lieu de rassemblement
    meeting_point = fields.Char(
        string='Lieu de rassemblement',
        required=True,
        tracking=True,
        help="Lieu où les passagers doivent se retrouver avant le départ",
    )
    meeting_point_address = fields.Text(
        string='Adresse détaillée',
    )
    meeting_point_latitude = fields.Float(
        string='Latitude',
        digits=(10, 7),
    )
    meeting_point_longitude = fields.Float(
        string='Longitude',
        digits=(10, 7),
    )
    meeting_time_before = fields.Integer(
        string='Arrivée avant départ (min)',
        default=30,
        help="Nombre de minutes avant le départ où les passagers doivent être présents",
    )
    
    # Tarification
    price = fields.Monetary(
        string='Prix du billet',
        currency_field='currency_id',
        required=True,
        tracking=True,
    )
    vip_price = fields.Monetary(
        string='Prix VIP',
        currency_field='currency_id',
    )
    child_price = fields.Monetary(
        string='Prix enfant',
        currency_field='currency_id',
        help="Prix pour les enfants de moins de 12 ans",
    )
    currency_id = fields.Many2one(
        related='transport_company_id.currency_id',
    )
    
    # Gestion bagages (hérité du bus mais modifiable)
    manage_luggage = fields.Boolean(
        string='Gérer les bagages',
        related='bus_id.manage_luggage',
        readonly=False,
        store=True,
    )
    luggage_included_kg = fields.Float(
        string='Bagages inclus (kg)',
        default=25,
    )
    extra_luggage_price = fields.Monetary(
        string='Prix kg supplémentaire',
        currency_field='currency_id',
    )
    
    # Capacité et disponibilité
    total_seats = fields.Integer(
        string='Places totales',
        related='bus_id.seat_capacity',
        store=True,
    )
    booking_quota = fields.Integer(
        string='Quota de réservations',
        default=lambda self: int(self.env['ir.config_parameter'].sudo().get_param(
            'transport_interurbain.default_booking_quota', default='0'
        )),
        tracking=True,
        help="Nombre maximum de réservations autorisées pour ce voyage. "
             "0 = pas de limite (utilise la capacité totale du bus).",
    )
    effective_quota = fields.Integer(
        string='Quota effectif',
        compute='_compute_seat_availability',
        store=True,
        help="Quota réel utilisé (quota défini ou capacité du bus si quota=0)",
    )
    booked_seats = fields.Integer(
        string='Places réservées',
        compute='_compute_seat_availability',
        store=True,
    )
    available_seats = fields.Integer(
        string='Places disponibles',
        compute='_compute_seat_availability',
        store=True,
    )
    occupancy_rate = fields.Float(
        string='Taux de remplissage (%)',
        compute='_compute_seat_availability',
        store=True,
    )
    
    # État
    state = fields.Selection([
        ('draft', 'Brouillon'),
        ('scheduled', 'Programmé'),
        ('boarding', 'Embarquement'),
        ('departed', 'En route'),
        ('arrived', 'Arrivé'),
        ('cancelled', 'Annulé'),
    ], string='État', default='draft', tracking=True, index=True)
    
    # Relations
    booking_ids = fields.One2many(
        'transport.booking',
        'trip_id',
        string='Réservations',
    )
    stop_times_ids = fields.One2many(
        'transport.trip.stop',
        'trip_id',
        string='Horaires des arrêts',
    )
    
    # Informations supplémentaires
    notes = fields.Text(
        string='Notes internes',
    )
    passenger_info = fields.Html(
        string='Informations passagers',
        help="Informations affichées aux passagers lors de la réservation",
    )
    is_recurring = fields.Boolean(
        string='Voyage récurrent',
        default=False,
    )
    is_published = fields.Boolean(
        string='Publié sur le site',
        default=True,
        tracking=True,
    )
    
    # Computed pour recherche
    departure_date = fields.Date(
        string='Date de départ',
        compute='_compute_departure_date',
        store=True,
        index=True,
    )

    _sql_constraints = [
        ('name_uniq', 'UNIQUE(name)', 'La référence du voyage doit être unique!'),
        ('price_positive', 'CHECK(price >= 0)', 'Le prix du billet doit être positif!'),
        ('vip_price_positive', 'CHECK(vip_price IS NULL OR vip_price >= 0)', 'Le prix VIP doit être positif!'),
        ('child_price_positive', 'CHECK(child_price IS NULL OR child_price >= 0)', 'Le prix enfant doit être positif!'),
        ('extra_luggage_price_positive', 'CHECK(extra_luggage_price IS NULL OR extra_luggage_price >= 0)', 
         'Le prix du bagage supplémentaire doit être positif!'),
        ('meeting_time_positive', 'CHECK(meeting_time_before >= 0)', 
         'Le temps d\'arrivée avant départ doit être positif!'),
    ]

    # =============================================
    # CONTRAINTES PYTHON
    # =============================================
    
    @api.constrains('departure_datetime')
    def _check_departure_datetime(self):
        """Vérifier que la date de départ est dans le futur pour les nouveaux voyages"""
        for trip in self:
            if trip.state == 'draft' and trip.departure_datetime:
                if trip.departure_datetime < fields.Datetime.now():
                    raise ValidationError(_(
                        "La date de départ doit être dans le futur pour le voyage %s!"
                    ) % trip.name)

    @api.constrains('bus_id', 'transport_company_id')
    def _check_bus_company(self):
        """Vérifier que le bus appartient à la compagnie"""
        for trip in self:
            if trip.bus_id and trip.transport_company_id:
                if trip.bus_id.transport_company_id != trip.transport_company_id:
                    raise ValidationError(_(
                        "Le bus '%s' n'appartient pas à la compagnie '%s'!"
                    ) % (trip.bus_id.name, trip.transport_company_id.name))

    @api.constrains('bus_id', 'departure_datetime')
    def _check_bus_availability(self):
        """Vérifier que le bus n'est pas déjà assigné à un autre voyage"""
        for trip in self:
            if trip.bus_id and trip.departure_datetime and trip.state != 'cancelled':
                # Chercher d'autres voyages avec le même bus le même jour
                conflicting = self.search([
                    ('id', '!=', trip.id),
                    ('bus_id', '=', trip.bus_id.id),
                    ('state', 'not in', ['cancelled', 'arrived']),
                    ('departure_date', '=', trip.departure_date),
                ], limit=1)
                if conflicting:
                    raise ValidationError(_(
                        "Le bus '%s' est déjà assigné au voyage '%s' le %s!"
                    ) % (trip.bus_id.name, conflicting.name, trip.departure_date))

    @api.constrains('price', 'vip_price', 'child_price')
    def _check_prices(self):
        """Vérifier la cohérence des prix"""
        for trip in self:
            if trip.vip_price and trip.vip_price < trip.price:
                raise ValidationError(_(
                    "Le prix VIP (%s) ne peut pas être inférieur au prix normal (%s)!"
                ) % (trip.vip_price, trip.price))
            if trip.child_price and trip.child_price > trip.price:
                raise ValidationError(_(
                    "Le prix enfant (%s) ne peut pas être supérieur au prix normal (%s)!"
                ) % (trip.child_price, trip.price))

    @api.constrains('bus_id', 'transport_company_id')
    def _check_bus_company(self):
        """Vérifier que le bus appartient à la compagnie"""
        for trip in self:
            if trip.bus_id and trip.transport_company_id:
                if trip.bus_id.transport_company_id != trip.transport_company_id:
                    raise ValidationError(_(
                        "Le bus '%s' n'appartient pas à la compagnie '%s'!"
                    ) % (trip.bus_id.name, trip.transport_company_id.name))

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if vals.get('name', '/') == '/':
                vals['name'] = self.env['ir.sequence'].next_by_code('transport.trip') or '/'
        trips = super().create(vals_list)
        # Créer les horaires des arrêts
        for trip in trips:
            trip._create_stop_times()
        return trips

    def _create_stop_times(self):
        """Créer les horaires des arrêts intermédiaires"""
        self.ensure_one()
        StopTime = self.env['transport.trip.stop']
        
        if not self.route_id.stop_ids:
            return
        
        for stop in self.route_id.stop_ids.sorted('sequence'):
            estimated_time = self.departure_datetime + timedelta(hours=stop.duration_from_start)
            StopTime.create({
                'trip_id': self.id,
                'route_stop_id': stop.id,
                'estimated_arrival': estimated_time,
                'price_from_start': stop.price_from_start,
                'price_to_end': stop.price_to_end,
            })

    @api.depends('departure_datetime')
    def _compute_departure_date(self):
        for trip in self:
            if trip.departure_datetime:
                trip.departure_date = trip.departure_datetime.date()
            else:
                trip.departure_date = False

    @api.depends('departure_datetime', 'route_id.estimated_duration')
    def _compute_arrival_datetime(self):
        for trip in self:
            if trip.departure_datetime and trip.route_id.estimated_duration:
                trip.arrival_datetime = trip.departure_datetime + timedelta(
                    hours=trip.route_id.estimated_duration
                )
            else:
                trip.arrival_datetime = False

    @api.depends('booking_ids', 'booking_ids.state', 'total_seats', 'booking_quota')
    def _compute_seat_availability(self):
        for trip in self:
            confirmed_bookings = trip.booking_ids.filtered(
                lambda b: b.state in ['reserved', 'confirmed']
            )
            trip.booked_seats = len(confirmed_bookings)
            # Le quota effectif est le quota défini, ou la capacité totale si quota = 0
            trip.effective_quota = trip.booking_quota if trip.booking_quota > 0 else trip.total_seats
            trip.available_seats = max(0, trip.effective_quota - trip.booked_seats)
            trip.occupancy_rate = (trip.booked_seats / trip.effective_quota * 100) if trip.effective_quota else 0

    @api.onchange('route_id')
    def _onchange_route_id(self):
        if self.route_id and self.route_id.base_price:
            self.price = self.route_id.base_price

    @api.onchange('bus_id')
    def _onchange_bus_id(self):
        if self.bus_id:
            self.manage_luggage = self.bus_id.manage_luggage
            self.luggage_included_kg = self.bus_id.luggage_per_passenger_kg
            self.extra_luggage_price = self.bus_id.extra_luggage_price_kg

    def action_schedule(self):
        """Programmer le voyage"""
        for trip in self:
            if trip.state != 'draft':
                raise UserError(_("Seuls les voyages en brouillon peuvent être programmés!"))
            
            # Validations supplémentaires
            if not trip.bus_id:
                raise UserError(_("Veuillez sélectionner un bus avant de programmer le voyage!"))
            if not trip.route_id:
                raise UserError(_("Veuillez sélectionner un itinéraire avant de programmer le voyage!"))
            if not trip.meeting_point:
                raise UserError(_("Veuillez définir le lieu de rassemblement!"))
            if trip.price <= 0:
                raise UserError(_("Le prix du billet doit être supérieur à zéro!"))
            if trip.departure_datetime < fields.Datetime.now():
                raise UserError(_("La date de départ doit être dans le futur!"))
            
            trip.write({'state': 'scheduled'})
            _logger.info("Voyage %s programmé par %s", trip.name, self.env.user.name)

    def action_start_boarding(self):
        """Démarrer l'embarquement"""
        for trip in self:
            if trip.state != 'scheduled':
                raise UserError(_("Le voyage doit être programmé pour démarrer l'embarquement!"))
            
            # Vérifier qu'il y a au moins une réservation confirmée
            confirmed_count = len(trip.booking_ids.filtered(lambda b: b.state in ['confirmed', 'reserved']))
            if confirmed_count == 0:
                raise UserError(_("Aucune réservation pour ce voyage! Veuillez annuler ou attendre des réservations."))
            
            trip.write({'state': 'boarding'})
            _logger.info("Embarquement démarré pour voyage %s (%d passagers)", trip.name, confirmed_count)

    def action_depart(self):
        """Marquer comme parti"""
        for trip in self:
            if trip.state not in ['scheduled', 'boarding']:
                raise UserError(_("Le voyage doit être en embarquement pour partir!"))
            
            # Marquer les réservations non embarquées comme no-show
            no_shows = trip.booking_ids.filtered(lambda b: b.state == 'confirmed')
            if no_shows:
                no_shows.write({'state': 'checked_in'})  # Considérer comme embarqués par défaut
            
            trip.write({
                'state': 'departed',
                'actual_departure': fields.Datetime.now(),
            })
            trip.bus_id.write({'state': 'in_trip'})
            # Expirer les réservations non confirmées
            trip._cancel_unconfirmed_reservations()
            _logger.info("Voyage %s parti à %s", trip.name, fields.Datetime.now())

    def action_arrive(self):
        """Marquer comme arrivé"""
        for trip in self:
            if trip.state != 'departed':
                raise UserError(_("Le voyage doit être en route pour arriver!"))
            trip.write({
                'state': 'arrived',
                'actual_arrival': fields.Datetime.now(),
            })
            trip.bus_id.write({'state': 'available'})
            # Marquer toutes les réservations comme terminées
            trip.booking_ids.filtered(lambda b: b.state == 'confirmed').write({
                'state': 'completed'
            })

    def action_cancel(self):
        """Annuler le voyage"""
        for trip in self:
            if trip.state in ['departed', 'arrived']:
                raise UserError(_("Impossible d'annuler un voyage en cours ou terminé!"))
            # Annuler et rembourser les réservations
            trip.booking_ids.filtered(
                lambda b: b.state in ['reserved', 'confirmed']
            ).action_cancel()
            trip.write({'state': 'cancelled'})

    def action_reset_draft(self):
        """Remettre en brouillon"""
        for trip in self:
            if trip.state not in ['cancelled', 'scheduled']:
                raise UserError(_("Seuls les voyages annulés ou programmés peuvent être remis en brouillon!"))
            trip.write({'state': 'draft'})

    def _cancel_unconfirmed_reservations(self):
        """Annuler les réservations non confirmées avant le départ"""
        self.ensure_one()
        unconfirmed = self.booking_ids.filtered(lambda b: b.state == 'reserved')
        unconfirmed.write({'state': 'expired'})

    def get_available_seats(self, boarding_stop=None, alighting_stop=None):
        """
        Calculer les places disponibles pour un segment donné.
        Prend en compte les passagers qui montent et descendent aux différents arrêts.
        """
        self.ensure_one()
        
        if not boarding_stop:
            boarding_stop = self.route_id.departure_city_id
        if not alighting_stop:
            alighting_stop = self.route_id.arrival_city_id
        
        # Récupérer toutes les réservations actives
        active_bookings = self.booking_ids.filtered(
            lambda b: b.state in ['reserved', 'confirmed']
        )
        
        # Calculer l'occupation pour chaque segment
        all_stops = [self.route_id.departure_city_id.id]
        all_stops.extend(self.route_id.stop_ids.sorted('sequence').mapped('city_id.id'))
        all_stops.append(self.route_id.arrival_city_id.id)
        
        if boarding_stop.id not in all_stops or alighting_stop.id not in all_stops:
            return 0
        
        boarding_idx = all_stops.index(boarding_stop.id)
        alighting_idx = all_stops.index(alighting_stop.id)
        
        if boarding_idx >= alighting_idx:
            return 0
        
        # Pour chaque segment entre boarding et alighting, calculer l'occupation
        max_occupation = 0
        for i in range(boarding_idx, alighting_idx):
            segment_occupation = 0
            for booking in active_bookings:
                # Trouver les indices de montée et descente de cette réservation
                book_boarding_idx = all_stops.index(booking.boarding_stop_id.id) if booking.boarding_stop_id else 0
                book_alighting_idx = all_stops.index(booking.alighting_stop_id.id) if booking.alighting_stop_id else len(all_stops) - 1
                
                # Si la réservation occupe ce segment
                if book_boarding_idx <= i < book_alighting_idx:
                    segment_occupation += 1
            
            max_occupation = max(max_occupation, segment_occupation)
        
        return self.total_seats - max_occupation

    def action_view_bookings(self):
        """Voir les réservations du voyage"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': _('Réservations - %s') % self.name,
            'res_model': 'transport.booking',
            'view_mode': 'tree,form',
            'domain': [('trip_id', '=', self.id)],
            'context': {'default_trip_id': self.id},
        }

    def action_view_seat_map(self):
        """Voir le plan des sièges"""
        self.ensure_one()
        return {
            'type': 'ir.actions.client',
            'tag': 'transport_seat_map',
            'params': {'trip_id': self.id},
            'name': _('Plan des sièges - %s') % self.name,
        }

    @api.model
    def get_trips_for_date(self, date, route_id=None, company_id=None):
        """Récupérer les voyages pour une date donnée (pour le portail)"""
        domain = [
            ('departure_date', '=', date),
            ('state', '=', 'scheduled'),
            ('is_published', '=', True),
        ]
        if route_id:
            domain.append(('route_id', '=', route_id))
        if company_id:
            domain.append(('transport_company_id', '=', company_id))
        
        return self.search(domain, order='departure_datetime')


class TransportTripStop(models.Model):
    """Horaires des arrêts pour un voyage"""
    _name = 'transport.trip.stop'
    _description = 'Horaire d\'arrêt'
    _order = 'sequence, estimated_arrival'

    trip_id = fields.Many2one(
        'transport.trip',
        string='Voyage',
        required=True,
        ondelete='cascade',
    )
    route_stop_id = fields.Many2one(
        'transport.route.stop',
        string='Arrêt',
        required=True,
    )
    city_id = fields.Many2one(
        related='route_stop_id.city_id',
        string='Ville',
        store=True,
    )
    sequence = fields.Integer(
        related='route_stop_id.sequence',
        store=True,
    )
    estimated_arrival = fields.Datetime(
        string='Arrivée estimée',
    )
    actual_arrival = fields.Datetime(
        string='Arrivée réelle',
    )
    estimated_departure = fields.Datetime(
        string='Départ estimé',
    )
    actual_departure = fields.Datetime(
        string='Départ réel',
    )
    stop_duration = fields.Integer(
        string='Durée d\'arrêt (min)',
        default=5,
    )
    price_from_start = fields.Monetary(
        string='Prix depuis départ',
        currency_field='currency_id',
    )
    price_to_end = fields.Monetary(
        string='Prix jusqu\'à arrivée',
        currency_field='currency_id',
    )
    boarding_count = fields.Integer(
        string='Montées',
        compute='_compute_passenger_counts',
    )
    alighting_count = fields.Integer(
        string='Descentes',
        compute='_compute_passenger_counts',
    )
    currency_id = fields.Many2one(
        related='trip_id.currency_id',
    )

    def _compute_passenger_counts(self):
        for stop in self:
            stop.boarding_count = self.env['transport.booking'].search_count([
                ('trip_id', '=', stop.trip_id.id),
                ('boarding_stop_id', '=', stop.city_id.id),
                ('state', 'in', ['reserved', 'confirmed']),
            ])
            stop.alighting_count = self.env['transport.booking'].search_count([
                ('trip_id', '=', stop.trip_id.id),
                ('alighting_stop_id', '=', stop.city_id.id),
                ('state', 'in', ['reserved', 'confirmed']),
            ])
