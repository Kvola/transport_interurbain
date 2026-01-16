# -*- coding: utf-8 -*-

from odoo import api, fields, models, _
from odoo.exceptions import ValidationError


class TransportBus(models.Model):
    """Modèle pour les bus/cars de transport"""
    _name = 'transport.bus'
    _description = 'Bus / Car'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _order = 'name'

    name = fields.Char(
        string='Nom / Immatriculation',
        required=True,
        tracking=True,
        index=True,
    )
    code = fields.Char(
        string='Code interne',
        required=True,
        copy=False,
        readonly=True,
        default='/',
        index=True,
    )
    transport_company_id = fields.Many2one(
        'transport.company',
        string='Compagnie',
        required=True,
        tracking=True,
        ondelete='cascade',
    )
    bus_type = fields.Selection([
        ('minibus', 'Minibus (8-15 places)'),
        ('midi', 'Midi-bus (16-30 places)'),
        ('standard', 'Bus standard (31-50 places)'),
        ('coach', 'Autocar (51-70 places)'),
        ('double_decker', 'Bus à étage (70+ places)'),
    ], string='Type de bus', default='standard', required=True, tracking=True)
    
    # Capacité passagers
    seat_capacity = fields.Integer(
        string='Nombre de places',
        required=True,
        tracking=True,
    )
    seat_layout = fields.Char(
        string='Configuration sièges',
        help="Ex: 2+2, 2+1, 3+2",
    )
    has_vip_seats = fields.Boolean(
        string='Places VIP',
        default=False,
    )
    vip_seat_count = fields.Integer(
        string='Nombre de places VIP',
    )
    vip_seat_numbers = fields.Char(
        string='Numéros places VIP',
        help="Ex: 1,2,3,4 ou 1-4",
    )
    
    # Gestion des bagages
    manage_luggage = fields.Boolean(
        string='Gérer les bagages',
        default=True,
        tracking=True,
    )
    luggage_capacity_kg = fields.Float(
        string='Capacité bagages (kg)',
        default=1000,
        tracking=True,
    )
    luggage_capacity_volume = fields.Float(
        string='Capacité bagages (m³)',
        default=10,
        tracking=True,
    )
    luggage_per_passenger_kg = fields.Float(
        string='Franchise bagage/passager (kg)',
        default=25,
        help="Poids de bagage inclus dans le prix du billet",
    )
    luggage_per_passenger_volume = fields.Float(
        string='Franchise volume/passager (m³)',
        default=0.1,
    )
    extra_luggage_price_kg = fields.Monetary(
        string='Prix kg supplémentaire',
        currency_field='currency_id',
    )
    
    # Équipements
    has_ac = fields.Boolean(
        string='Climatisation',
        default=True,
    )
    has_wifi = fields.Boolean(
        string='WiFi',
        default=False,
    )
    has_toilet = fields.Boolean(
        string='Toilettes',
        default=False,
    )
    has_tv = fields.Boolean(
        string='TV/Écrans',
        default=False,
    )
    has_usb = fields.Boolean(
        string='Prises USB',
        default=False,
    )
    has_reclining_seats = fields.Boolean(
        string='Sièges inclinables',
        default=True,
    )
    
    # Informations techniques
    make = fields.Char(
        string='Marque',
    )
    model = fields.Char(
        string='Modèle',
    )
    year = fields.Integer(
        string='Année',
    )
    license_plate = fields.Char(
        string='Immatriculation',
    )
    image = fields.Binary(
        string='Photo',
        attachment=True,
    )
    
    currency_id = fields.Many2one(
        related='transport_company_id.currency_id',
    )
    active = fields.Boolean(
        default=True,
    )
    state = fields.Selection([
        ('available', 'Disponible'),
        ('in_trip', 'En voyage'),
        ('maintenance', 'En maintenance'),
        ('out_of_service', 'Hors service'),
    ], string='État', default='available', tracking=True)
    
    # Statistiques
    trip_count = fields.Integer(
        string='Nombre de voyages',
        compute='_compute_trip_count',
    )
    
    # Sièges
    seat_ids = fields.One2many(
        'transport.bus.seat',
        'bus_id',
        string='Sièges',
    )

    _sql_constraints = [
        ('code_uniq', 'UNIQUE(code)', 'Le code du bus doit être unique!'),
        ('seat_capacity_positive', 'CHECK(seat_capacity > 0)',
         'Le nombre de places doit être positif!'),
    ]

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if vals.get('code', '/') == '/':
                vals['code'] = self.env['ir.sequence'].next_by_code('transport.bus') or '/'
        buses = super().create(vals_list)
        # Créer les sièges automatiquement
        for bus in buses:
            bus._create_seats()
        return buses

    def _create_seats(self):
        """Créer les sièges du bus automatiquement"""
        self.ensure_one()
        Seat = self.env['transport.bus.seat']
        vip_numbers = self._parse_vip_seats()
        
        for i in range(1, self.seat_capacity + 1):
            Seat.create({
                'bus_id': self.id,
                'seat_number': str(i),
                'seat_type': 'vip' if i in vip_numbers else 'standard',
            })

    def _parse_vip_seats(self):
        """Parser les numéros de sièges VIP"""
        if not self.vip_seat_numbers:
            return set()
        
        vip_seats = set()
        parts = self.vip_seat_numbers.replace(' ', '').split(',')
        for part in parts:
            if '-' in part:
                start, end = part.split('-')
                vip_seats.update(range(int(start), int(end) + 1))
            else:
                vip_seats.add(int(part))
        return vip_seats

    def _compute_trip_count(self):
        for bus in self:
            bus.trip_count = self.env['transport.trip'].search_count([
                ('bus_id', '=', bus.id),
            ])

    def action_set_available(self):
        """Marquer comme disponible"""
        self.write({'state': 'available'})

    def action_set_maintenance(self):
        """Mettre en maintenance"""
        self.write({'state': 'maintenance'})

    def action_view_trips(self):
        """Voir les voyages de ce bus"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': _('Voyages - %s') % self.name,
            'res_model': 'transport.trip',
            'view_mode': 'tree,form,calendar',
            'domain': [('bus_id', '=', self.id)],
            'context': {'default_bus_id': self.id, 'default_transport_company_id': self.transport_company_id.id},
        }

    def regenerate_seats(self):
        """Regénérer les sièges du bus"""
        self.ensure_one()
        # Vérifier qu'il n'y a pas de réservations actives
        active_bookings = self.env['transport.booking'].search_count([
            ('seat_id.bus_id', '=', self.id),
            ('state', 'in', ['reserved', 'confirmed']),
        ])
        if active_bookings:
            raise ValidationError(_("Impossible de regénérer les sièges : il y a des réservations actives!"))
        
        self.seat_ids.unlink()
        self._create_seats()
        return True


class TransportBusSeat(models.Model):
    """Siège individuel dans un bus"""
    _name = 'transport.bus.seat'
    _description = 'Siège de bus'
    _order = 'bus_id, seat_number'

    bus_id = fields.Many2one(
        'transport.bus',
        string='Bus',
        required=True,
        ondelete='cascade',
    )
    seat_number = fields.Char(
        string='Numéro de siège',
        required=True,
    )
    seat_type = fields.Selection([
        ('standard', 'Standard'),
        ('vip', 'VIP'),
        ('handicap', 'PMR'),
    ], string='Type', default='standard')
    row = fields.Integer(
        string='Rangée',
    )
    position = fields.Selection([
        ('window_left', 'Fenêtre gauche'),
        ('aisle_left', 'Couloir gauche'),
        ('aisle_right', 'Couloir droite'),
        ('window_right', 'Fenêtre droite'),
    ], string='Position')
    is_available = fields.Boolean(
        string='Disponible',
        default=True,
    )
    notes = fields.Char(
        string='Notes',
    )

    _sql_constraints = [
        ('seat_bus_uniq', 'UNIQUE(bus_id, seat_number)',
         'Le numéro de siège doit être unique par bus!'),
    ]

    def name_get(self):
        return [(seat.id, f"{seat.bus_id.name} - Siège {seat.seat_number}") for seat in self]
