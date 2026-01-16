# -*- coding: utf-8 -*-

from odoo import api, fields, models, _
from odoo.exceptions import ValidationError, UserError
from odoo.tools import float_compare, float_is_zero
from datetime import datetime, timedelta
import uuid
import qrcode
import base64
from io import BytesIO
import re
import logging

_logger = logging.getLogger(__name__)


class TransportBooking(models.Model):
    """Réservation de ticket"""
    _name = 'transport.booking'
    _description = 'Réservation de ticket'
    _inherit = ['mail.thread', 'mail.activity.mixin', 'portal.mixin']
    _order = 'create_date desc'

    name = fields.Char(
        string='Numéro de ticket',
        required=True,
        copy=False,
        readonly=True,
        default='/',
        index=True,
    )
    trip_id = fields.Many2one(
        'transport.trip',
        string='Voyage',
        required=True,
        tracking=True,
        ondelete='restrict',
        index=True,
    )
    partner_id = fields.Many2one(
        'res.partner',
        string='Client',
        required=True,
        tracking=True,
        index=True,
    )
    passenger_id = fields.Many2one(
        'transport.passenger',
        string='Passager',
        tracking=True,
    )
    
    # Informations passager (si différent du client)
    passenger_name = fields.Char(
        string='Nom du passager',
        required=True,
    )
    passenger_phone = fields.Char(
        string='Téléphone passager',
    )
    passenger_email = fields.Char(
        string='Email passager',
    )
    passenger_id_type = fields.Selection([
        ('cni', 'CNI'),
        ('passport', 'Passeport'),
        ('permis', 'Permis de conduire'),
        ('other', 'Autre'),
    ], string='Type de pièce d\'identité')
    passenger_id_number = fields.Char(
        string='Numéro de pièce',
    )
    
    # ==================== ACHAT POUR UN TIERS ====================
    is_for_other = fields.Boolean(
        string='Achat pour un tiers',
        default=False,
        help="Coché si le billet a été acheté par quelqu'un d'autre pour ce passager",
    )
    buyer_id = fields.Many2one(
        'transport.passenger',
        string='Acheteur',
        help="L'usager qui a acheté le billet (si différent du voyageur)",
    )
    buyer_name = fields.Char(
        string='Nom de l\'acheteur',
    )
    buyer_phone = fields.Char(
        string='Téléphone de l\'acheteur',
    )
    
    # Informations d'identité du voyageur (pour les achats tiers)
    traveler_name = fields.Char(
        string='Nom du voyageur',
        help="Nom du voyageur si différent du profil passager",
    )
    traveler_phone = fields.Char(
        string='Téléphone du voyageur',
        help="Téléphone du voyageur si différent du profil passager",
    )
    traveler_email = fields.Char(
        string='Email du voyageur',
    )
    traveler_id_type = fields.Selection([
        ('cni', 'CNI'),
        ('passport', 'Passeport'),
        ('permis', 'Permis de conduire'),
        ('other', 'Autre'),
    ], string='Pièce d\'identité voyageur')
    traveler_id_number = fields.Char(
        string='N° pièce voyageur',
    )
    
    # Siège
    seat_id = fields.Many2one(
        'transport.bus.seat',
        string='Siège',
        domain="[('bus_id', '=', bus_id)]",
        tracking=True,
    )
    seat_number = fields.Char(
        string='Numéro de siège',
        related='seat_id.seat_number',
        store=True,
    )
    seat_type = fields.Selection(
        related='seat_id.seat_type',
        string='Type de siège',
    )
    
    # Points de montée/descente
    boarding_stop_id = fields.Many2one(
        'transport.city',
        string='Point de montée',
        tracking=True,
        help="Arrêt où le passager monte",
    )
    alighting_stop_id = fields.Many2one(
        'transport.city',
        string='Point de descente',
        tracking=True,
        help="Arrêt où le passager descend",
    )
    
    # Tarification
    ticket_price = fields.Monetary(
        string='Prix du billet',
        currency_field='currency_id',
        required=True,
        tracking=True,
    )
    ticket_type = fields.Selection([
        ('adult', 'Adulte'),
        ('child', 'Enfant'),
        ('vip', 'VIP'),
    ], string='Type de billet', default='adult', tracking=True)
    
    # Bagages
    luggage_weight = fields.Float(
        string='Poids bagages (kg)',
    )
    luggage_extra_kg = fields.Float(
        string='Excédent bagages (kg)',
        compute='_compute_luggage_extra',
        store=True,
    )
    luggage_extra_price = fields.Monetary(
        string='Supplément bagages',
        currency_field='currency_id',
        compute='_compute_luggage_extra',
        store=True,
    )
    luggage_type = fields.Selection([
        ('hand', 'Bagage à main'),
        ('checked', 'Bagage en soute'),
        ('both', 'Les deux'),
    ], string='Type de bagage', default='checked')
    luggage_count = fields.Integer(
        string='Nombre de bagages',
        default=1,
    )
    
    # Total
    total_amount = fields.Monetary(
        string='Montant total',
        currency_field='currency_id',
        compute='_compute_total_amount',
        store=True,
        tracking=True,
    )
    amount_paid = fields.Monetary(
        string='Montant payé',
        currency_field='currency_id',
        tracking=True,
    )
    amount_due = fields.Monetary(
        string='Reste à payer',
        currency_field='currency_id',
        compute='_compute_amount_due',
        store=True,
    )
    
    # Type de réservation
    booking_type = fields.Selection([
        ('reservation', 'Réservation (temporaire)'),
        ('purchase', 'Achat (définitif)'),
    ], string='Type', default='reservation', tracking=True)
    reservation_fee = fields.Monetary(
        string='Frais de réservation',
        currency_field='currency_id',
    )
    reservation_deadline = fields.Datetime(
        string='Date limite de paiement',
        compute='_compute_reservation_deadline',
        store=True,
    )
    
    # Paiement
    payment_method = fields.Selection([
        ('cash', 'Espèces'),
        ('wave', 'Wave'),
        ('mobile_money', 'Mobile Money'),
        ('card', 'Carte bancaire'),
    ], string='Mode de paiement', tracking=True)
    payment_reference = fields.Char(
        string='Référence paiement',
    )
    payment_date = fields.Datetime(
        string='Date de paiement',
    )
    payment_ids = fields.One2many(
        'transport.payment',
        'booking_id',
        string='Paiements',
    )
    
    # Aller-retour
    is_round_trip = fields.Boolean(
        string='Aller-retour',
        default=False,
        tracking=True,
    )
    return_booking_id = fields.Many2one(
        'transport.booking',
        string='Billet retour',
        tracking=True,
    )
    return_trip_id = fields.Many2one(
        'transport.trip',
        string='Voyage retour',
        tracking=True,
    )
    
    # État
    state = fields.Selection([
        ('draft', 'Brouillon'),
        ('reserved', 'Réservé'),
        ('confirmed', 'Confirmé'),
        ('checked_in', 'Embarqué'),
        ('completed', 'Terminé'),
        ('cancelled', 'Annulé'),
        ('expired', 'Expiré'),
        ('refunded', 'Remboursé'),
    ], string='État', default='draft', tracking=True, index=True)
    
    # Date de réservation
    booking_date = fields.Date(
        string='Date de réservation',
        default=fields.Date.today,
        required=True,
        index=True,
        tracking=True,
    )
    
    # QR Code
    qr_code = fields.Binary(
        string='QR Code',
        compute='_compute_qr_code',
        store=True,
    )
    ticket_token = fields.Char(
        string='Token',
        copy=False,
        default=lambda self: str(uuid.uuid4()),
    )
    
    # Token de partage (différent du ticket_token pour plus de sécurité)
    share_token = fields.Char(
        string='Token de partage',
        copy=False,
        help="Token unique pour partager le billet via un lien public",
    )
    share_url = fields.Char(
        string='URL de partage',
        compute='_compute_share_url',
    )
    
    # Évaluation
    rating = fields.Integer(
        string='Note',
        help="Note de 1 à 5",
    )
    rating_comment = fields.Text(
        string='Commentaire',
    )
    
    # Relations calculées
    transport_company_id = fields.Many2one(
        related='trip_id.transport_company_id',
        string='Compagnie',
        store=True,
    )
    route_id = fields.Many2one(
        related='trip_id.route_id',
        string='Itinéraire',
        store=True,
    )
    bus_id = fields.Many2one(
        related='trip_id.bus_id',
        string='Bus',
        store=True,
    )
    departure_datetime = fields.Datetime(
        related='trip_id.departure_datetime',
        string='Date de départ',
        store=True,
    )
    currency_id = fields.Many2one(
        related='trip_id.currency_id',
    )

    _sql_constraints = [
        ('name_uniq', 'UNIQUE(name)', 'Le numéro de ticket doit être unique!'),
        ('rating_range', 'CHECK(rating IS NULL OR (rating >= 1 AND rating <= 5))',
         'La note doit être entre 1 et 5!'),
        ('ticket_price_positive', 'CHECK(ticket_price >= 0)', 'Le prix du billet doit être positif!'),
        ('luggage_weight_positive', 'CHECK(luggage_weight IS NULL OR luggage_weight >= 0)', 
         'Le poids des bagages doit être positif!'),
        ('luggage_count_positive', 'CHECK(luggage_count IS NULL OR luggage_count >= 0)', 
         'Le nombre de bagages doit être positif!'),
        ('amount_paid_positive', 'CHECK(amount_paid IS NULL OR amount_paid >= 0)', 
         'Le montant payé doit être positif!'),
    ]

    # =============================================
    # CONTRAINTES PYTHON
    # =============================================

    @api.constrains('passenger_phone')
    def _check_passenger_phone(self):
        """Valider le format du numéro de téléphone"""
        phone_pattern = re.compile(r'^[\d\s\+\-\.]{8,20}$')
        for booking in self:
            if booking.passenger_phone:
                cleaned = booking.passenger_phone.strip()
                if not phone_pattern.match(cleaned):
                    raise ValidationError(_(
                        "Le numéro de téléphone '%s' n'est pas valide. "
                        "Utilisez le format: +225 XX XX XX XX XX"
                    ) % booking.passenger_phone)

    @api.constrains('passenger_email')
    def _check_passenger_email(self):
        """Valider le format de l'email"""
        email_pattern = re.compile(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
        for booking in self:
            if booking.passenger_email:
                if not email_pattern.match(booking.passenger_email.strip()):
                    raise ValidationError(_(
                        "L'adresse email '%s' n'est pas valide!"
                    ) % booking.passenger_email)

    @api.constrains('trip_id', 'state')
    def _check_booking_quota(self):
        """Vérifier que le quota de réservations n'est pas dépassé"""
        for booking in self:
            if booking.trip_id and booking.state in ['reserved', 'confirmed', 'checked_in']:
                trip = booking.trip_id
                # Forcer le recalcul du quota
                trip._compute_seat_availability()
                
                # Compter les réservations confirmées (excluant la réservation courante pour éviter double comptage)
                confirmed_count = self.search_count([
                    ('id', '!=', booking.id),
                    ('trip_id', '=', trip.id),
                    ('state', 'in', ['reserved', 'confirmed', 'checked_in']),
                ])
                
                # Calculer le quota effectif
                effective_quota = trip.booking_quota if trip.booking_quota > 0 else trip.total_seats
                
                if confirmed_count >= effective_quota:
                    raise ValidationError(_(
                        "Le quota de réservations pour le voyage '%s' est atteint (%d/%d). "
                        "Aucune réservation supplémentaire n'est possible."
                    ) % (trip.name, confirmed_count, effective_quota))

    @api.constrains('trip_id', 'seat_id')
    def _check_seat_trip(self):
        """Vérifier que le siège appartient au bus du voyage"""
        for booking in self:
            if booking.seat_id and booking.trip_id:
                if booking.seat_id.bus_id != booking.trip_id.bus_id:
                    raise ValidationError(_(
                        "Le siège '%s' n'appartient pas au bus '%s' de ce voyage!"
                    ) % (booking.seat_id.seat_number, booking.trip_id.bus_id.name))

    @api.constrains('seat_id', 'trip_id', 'state')
    def _check_seat_availability(self):
        """Vérifier que le siège n'est pas déjà réservé"""
        for booking in self:
            if booking.seat_id and booking.state in ['reserved', 'confirmed', 'checked_in']:
                conflicting = self.search([
                    ('id', '!=', booking.id),
                    ('trip_id', '=', booking.trip_id.id),
                    ('seat_id', '=', booking.seat_id.id),
                    ('state', 'in', ['reserved', 'confirmed', 'checked_in']),
                ], limit=1)
                if conflicting:
                    raise ValidationError(_(
                        "Le siège %s est déjà réservé par %s!"
                    ) % (booking.seat_id.seat_number, conflicting.passenger_name))

    @api.constrains('boarding_stop_id', 'alighting_stop_id', 'trip_id')
    def _check_stops(self):
        """Vérifier que les arrêts de montée et descente sont valides"""
        for booking in self:
            if booking.boarding_stop_id and booking.alighting_stop_id and booking.trip_id:
                route = booking.trip_id.route_id
                valid_stops = [route.departure_city_id.id]
                valid_stops.extend(route.stop_ids.mapped('city_id.id'))
                valid_stops.append(route.arrival_city_id.id)
                
                if booking.boarding_stop_id.id not in valid_stops:
                    raise ValidationError(_(
                        "L'arrêt de montée '%s' n'est pas sur cet itinéraire!"
                    ) % booking.boarding_stop_id.name)
                
                if booking.alighting_stop_id.id not in valid_stops:
                    raise ValidationError(_(
                        "L'arrêt de descente '%s' n'est pas sur cet itinéraire!"
                    ) % booking.alighting_stop_id.name)
                
                # Vérifier l'ordre des arrêts
                boarding_idx = valid_stops.index(booking.boarding_stop_id.id)
                alighting_idx = valid_stops.index(booking.alighting_stop_id.id)
                if boarding_idx >= alighting_idx:
                    raise ValidationError(_(
                        "L'arrêt de descente doit être après l'arrêt de montée!"
                    ))

    @api.constrains('luggage_weight', 'trip_id')
    def _check_luggage_weight(self):
        """Vérifier les limites de poids des bagages"""
        for booking in self:
            if booking.luggage_weight and booking.trip_id.bus_id:
                max_weight = booking.trip_id.bus_id.max_luggage_per_passenger_kg or 50
                if booking.luggage_weight > max_weight:
                    raise ValidationError(_(
                        "Le poids maximum autorisé par passager est de %s kg. "
                        "Vous avez déclaré %s kg."
                    ) % (max_weight, booking.luggage_weight))

    @api.constrains('amount_paid', 'total_amount')
    def _check_amount_paid(self):
        """Vérifier que le montant payé ne dépasse pas le total"""
        for booking in self:
            if booking.amount_paid and booking.total_amount:
                if float_compare(booking.amount_paid, booking.total_amount, precision_digits=2) > 0:
                    raise ValidationError(_(
                        "Le montant payé (%s) ne peut pas dépasser le montant total (%s)!"
                    ) % (booking.amount_paid, booking.total_amount))

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if vals.get('name', '/') == '/':
                vals['name'] = self.env['ir.sequence'].next_by_code('transport.booking') or '/'
            # Remplir le nom du passager depuis le partenaire si non fourni
            if not vals.get('passenger_name') and vals.get('partner_id'):
                partner = self.env['res.partner'].browse(vals['partner_id'])
                vals['passenger_name'] = partner.name
                vals['passenger_phone'] = partner.phone or partner.mobile
                vals['passenger_email'] = partner.email
        return super().create(vals_list)

    @api.depends('trip_id.manage_luggage', 'luggage_weight', 'trip_id.luggage_included_kg', 'trip_id.extra_luggage_price')
    def _compute_luggage_extra(self):
        for booking in self:
            if booking.trip_id.manage_luggage and booking.luggage_weight:
                included = booking.trip_id.luggage_included_kg
                extra = max(0, booking.luggage_weight - included)
                booking.luggage_extra_kg = extra
                booking.luggage_extra_price = extra * booking.trip_id.extra_luggage_price
            else:
                booking.luggage_extra_kg = 0
                booking.luggage_extra_price = 0

    @api.depends('ticket_price', 'luggage_extra_price', 'reservation_fee')
    def _compute_total_amount(self):
        for booking in self:
            booking.total_amount = (
                booking.ticket_price + 
                booking.luggage_extra_price + 
                (booking.reservation_fee if booking.booking_type == 'reservation' else 0)
            )

    @api.depends('total_amount', 'amount_paid')
    def _compute_amount_due(self):
        for booking in self:
            booking.amount_due = booking.total_amount - booking.amount_paid

    @api.depends('booking_type', 'create_date', 'transport_company_id.reservation_duration_hours')
    def _compute_reservation_deadline(self):
        for booking in self:
            if booking.booking_type == 'reservation' and booking.create_date:
                hours = booking.transport_company_id.reservation_duration_hours or 24
                booking.reservation_deadline = booking.create_date + timedelta(hours=hours)
            else:
                booking.reservation_deadline = False

    @api.depends('ticket_token', 'name', 'state')
    def _compute_qr_code(self):
        for booking in self:
            if booking.ticket_token and booking.state in ['confirmed', 'checked_in']:
                # Générer le QR code
                qr_data = f"TICKET:{booking.name}|TOKEN:{booking.ticket_token}|TRIP:{booking.trip_id.name}"
                qr = qrcode.QRCode(
                    version=1,
                    error_correction=qrcode.constants.ERROR_CORRECT_L,
                    box_size=10,
                    border=4,
                )
                qr.add_data(qr_data)
                qr.make(fit=True)
                img = qr.make_image(fill_color="black", back_color="white")
                buffer = BytesIO()
                img.save(buffer, format='PNG')
                booking.qr_code = base64.b64encode(buffer.getvalue())
            else:
                booking.qr_code = False

    @api.depends('share_token')
    def _compute_share_url(self):
        """Calcule l'URL de partage public du billet"""
        base_url = self.env['ir.config_parameter'].sudo().get_param('web.base.url')
        for booking in self:
            if booking.share_token:
                booking.share_url = f"{base_url}/ticket/share/{booking.share_token}"
            else:
                booking.share_url = False

    def action_generate_share_token(self):
        """Génère un token de partage unique pour le billet"""
        self.ensure_one()
        if not self.share_token:
            self.share_token = str(uuid.uuid4())[:12].upper()
        return {
            'share_token': self.share_token,
            'share_url': self.share_url,
        }

    @api.onchange('trip_id')
    def _onchange_trip_id(self):
        if self.trip_id:
            self.ticket_price = self.trip_id.price
            self.boarding_stop_id = self.trip_id.route_id.departure_city_id
            self.alighting_stop_id = self.trip_id.route_id.arrival_city_id
            if self.trip_id.transport_company_id:
                self.reservation_fee = self.trip_id.transport_company_id.reservation_fee

    @api.onchange('partner_id')
    def _onchange_partner_id(self):
        if self.partner_id:
            self.passenger_name = self.partner_id.name
            self.passenger_phone = self.partner_id.phone or self.partner_id.mobile
            self.passenger_email = self.partner_id.email

    @api.onchange('ticket_type')
    def _onchange_ticket_type(self):
        if self.trip_id:
            if self.ticket_type == 'vip':
                self.ticket_price = self.trip_id.vip_price or self.trip_id.price
            elif self.ticket_type == 'child':
                self.ticket_price = self.trip_id.child_price or self.trip_id.price * 0.5
            else:
                self.ticket_price = self.trip_id.price

    def action_reserve(self):
        """Effectuer une réservation temporaire"""
        for booking in self:
            if booking.state != 'draft':
                raise UserError(_("Cette réservation n'est plus en brouillon!"))
            
            # Vérifications complètes
            if not booking.passenger_name:
                raise UserError(_("Veuillez renseigner le nom du passager!"))
            if not booking.passenger_phone:
                raise UserError(_("Veuillez renseigner le téléphone du passager!"))
            if not booking.trip_id:
                raise UserError(_("Veuillez sélectionner un voyage!"))
            
            # Vérifier que le voyage est encore ouvert aux réservations
            if booking.trip_id.state not in ['scheduled']:
                raise UserError(_("Ce voyage n'accepte plus de réservations (état: %s)!") % booking.trip_id.state)
            
            # Vérifier que le voyage n'est pas dans le passé
            if booking.trip_id.departure_datetime < fields.Datetime.now():
                raise UserError(_("Impossible de réserver pour un voyage passé!"))
            
            # Vérifier la disponibilité
            available = booking.trip_id.get_available_seats(
                booking.boarding_stop_id,
                booking.alighting_stop_id
            )
            if available <= 0:
                raise UserError(_(
                    "Plus de places disponibles pour le trajet %s → %s!"
                ) % (booking.boarding_stop_id.name, booking.alighting_stop_id.name))
            
            booking.write({
                'state': 'reserved',
                'booking_type': 'reservation',
            })
            _logger.info("Réservation %s créée par %s pour %s", 
                        booking.name, self.env.user.name, booking.passenger_name)
            # Envoyer notification
            booking._send_reservation_notification()

    def action_confirm(self):
        """Confirmer la réservation (après paiement)"""
        for booking in self:
            if booking.state not in ['draft', 'reserved']:
                raise UserError(_("Cette réservation ne peut pas être confirmée (état: %s)!") % booking.state)
            
            # Vérifier que le voyage est toujours valide
            if booking.trip_id.state not in ['scheduled', 'boarding']:
                raise UserError(_(
                    "Le voyage '%s' n'est plus disponible (état: %s)!"
                ) % (booking.trip_id.name, booking.trip_id.state))
            
            # Vérifier le paiement
            if not float_is_zero(booking.amount_due, precision_digits=2):
                raise UserError(_(
                    "Le paiement complet est requis pour confirmer la réservation! "
                    "Reste à payer: %s FCFA"
                ) % booking.amount_due)
            
            booking.write({
                'state': 'confirmed',
                'booking_type': 'purchase',
                'payment_date': fields.Datetime.now(),
            })
            _logger.info("Réservation %s confirmée - Passager: %s", booking.name, booking.passenger_name)
            # Envoyer le ticket
            booking._send_ticket_notification()

    def action_check_in(self):
        """Marquer le passager comme embarqué"""
        for booking in self:
            if booking.state != 'confirmed':
                raise UserError(_("Seuls les billets confirmés peuvent être embarqués!"))
            booking.write({'state': 'checked_in'})

    def action_cancel(self):
        """Annuler la réservation"""
        for booking in self:
            if booking.state in ['checked_in', 'completed']:
                raise UserError(_("Impossible d'annuler un billet embarqué ou terminé!"))
            
            # Traiter le remboursement si nécessaire
            if booking.amount_paid > 0:
                booking._process_refund()
            
            booking.write({'state': 'cancelled'})

    def action_refund(self):
        """Rembourser le billet"""
        for booking in self:
            if booking.state != 'cancelled':
                raise UserError(_("Seuls les billets annulés peuvent être remboursés!"))
            booking._process_refund()
            booking.write({'state': 'refunded'})

    def _process_refund(self):
        """Traiter le remboursement"""
        self.ensure_one()
        # TODO: Implémenter la logique de remboursement Wave
        pass

    def _send_reservation_notification(self):
        """Envoyer une notification de réservation"""
        self.ensure_one()
        # TODO: Implémenter l'envoi de SMS/Email
        pass

    def _send_ticket_notification(self):
        """Envoyer le ticket par email/SMS"""
        self.ensure_one()
        # TODO: Implémenter l'envoi du ticket
        pass

    @api.model
    def cron_expire_reservations(self):
        """Tâche planifiée pour expirer les réservations non payées"""
        expired = self.search([
            ('state', '=', 'reserved'),
            ('booking_type', '=', 'reservation'),
            ('reservation_deadline', '<', fields.Datetime.now()),
        ])
        expired.write({'state': 'expired'})
        return True

    def _get_report_filename(self):
        """Nom du fichier pour le rapport de ticket"""
        return f"Ticket-{self.name}"

    def action_print_ticket(self):
        """Imprimer le ticket"""
        return self.env.ref('transport_interurbain.action_report_ticket').report_action(self)

    def _compute_access_url(self):
        super()._compute_access_url()
        for booking in self:
            booking.access_url = f'/my/bookings/{booking.id}'
