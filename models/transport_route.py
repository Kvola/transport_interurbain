# -*- coding: utf-8 -*-

from odoo import api, fields, models, _
from odoo.exceptions import ValidationError


class TransportRoute(models.Model):
    """Modèle pour les itinéraires de voyage"""
    _name = 'transport.route'
    _description = 'Itinéraire de voyage'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _order = 'name'

    name = fields.Char(
        string='Nom de l\'itinéraire',
        compute='_compute_name',
        store=True,
        readonly=False,
    )
    code = fields.Char(
        string='Code',
        required=True,
        copy=False,
        readonly=True,
        default='/',
        index=True,
    )
    departure_city_id = fields.Many2one(
        'transport.city',
        string='Ville de départ',
        required=True,
        tracking=True,
        index=True,
    )
    arrival_city_id = fields.Many2one(
        'transport.city',
        string='Ville d\'arrivée',
        required=True,
        tracking=True,
        index=True,
    )
    stop_ids = fields.One2many(
        'transport.route.stop',
        'route_id',
        string='Arrêts intermédiaires',
    )
    distance_km = fields.Float(
        string='Distance (km)',
        tracking=True,
    )
    estimated_duration = fields.Float(
        string='Durée estimée (heures)',
        tracking=True,
        help="Durée estimée du trajet en heures",
    )
    base_price = fields.Monetary(
        string='Prix de base',
        currency_field='currency_id',
        tracking=True,
        help="Prix de base suggéré pour ce trajet (les compagnies peuvent modifier)",
    )
    currency_id = fields.Many2one(
        'res.currency',
        string='Devise',
        default=lambda self: self.env['res.currency'].search([('name', '=', 'XOF')], limit=1),
    )
    description = fields.Text(
        string='Description',
    )
    active = fields.Boolean(
        default=True,
    )
    state = fields.Selection([
        ('draft', 'Brouillon'),
        ('active', 'Actif'),
        ('suspended', 'Suspendu'),
    ], string='État', default='draft', tracking=True)
    
    # Statistiques
    trip_count = fields.Integer(
        string='Nombre de voyages',
        compute='_compute_trip_count',
    )
    stop_count = fields.Integer(
        string='Nombre d\'arrêts',
        compute='_compute_stop_count',
    )

    _sql_constraints = [
        ('code_uniq', 'UNIQUE(code)', 'Le code de l\'itinéraire doit être unique!'),
        ('different_cities', 'CHECK(departure_city_id != arrival_city_id)', 
         'La ville de départ et d\'arrivée doivent être différentes!'),
    ]

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if vals.get('code', '/') == '/':
                vals['code'] = self.env['ir.sequence'].next_by_code('transport.route') or '/'
        return super().create(vals_list)

    @api.depends('departure_city_id', 'arrival_city_id')
    def _compute_name(self):
        for route in self:
            if route.departure_city_id and route.arrival_city_id:
                route.name = f"{route.departure_city_id.name} → {route.arrival_city_id.name}"
            else:
                route.name = '/'

    def _compute_trip_count(self):
        for route in self:
            route.trip_count = self.env['transport.trip'].search_count([
                ('route_id', '=', route.id),
            ])

    @api.depends('stop_ids')
    def _compute_stop_count(self):
        for route in self:
            route.stop_count = len(route.stop_ids)

    def action_activate(self):
        """Activer l'itinéraire"""
        self.write({'state': 'active'})

    def action_suspend(self):
        """Suspendre l'itinéraire"""
        self.write({'state': 'suspended'})

    def action_draft(self):
        """Remettre en brouillon"""
        self.write({'state': 'draft'})

    def action_view_trips(self):
        """Voir les voyages sur cet itinéraire"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': _('Voyages - %s') % self.name,
            'res_model': 'transport.trip',
            'view_mode': 'tree,form,calendar',
            'domain': [('route_id', '=', self.id)],
            'context': {'default_route_id': self.id},
        }


class TransportRouteStop(models.Model):
    """Arrêts intermédiaires sur un itinéraire"""
    _name = 'transport.route.stop'
    _description = 'Arrêt intermédiaire'
    _order = 'sequence, id'

    route_id = fields.Many2one(
        'transport.route',
        string='Itinéraire',
        required=True,
        ondelete='cascade',
    )
    city_id = fields.Many2one(
        'transport.city',
        string='Ville/Arrêt',
        required=True,
    )
    sequence = fields.Integer(
        string='Séquence',
        default=10,
    )
    distance_from_start = fields.Float(
        string='Distance depuis départ (km)',
    )
    duration_from_start = fields.Float(
        string='Durée depuis départ (h)',
    )
    price_from_start = fields.Monetary(
        string='Prix depuis départ',
        currency_field='currency_id',
    )
    price_to_end = fields.Monetary(
        string='Prix jusqu\'à arrivée',
        currency_field='currency_id',
    )
    currency_id = fields.Many2one(
        related='route_id.currency_id',
    )
    is_boarding_point = fields.Boolean(
        string='Point d\'embarquement',
        default=True,
        help="Les passagers peuvent monter à cet arrêt",
    )
    is_dropoff_point = fields.Boolean(
        string='Point de descente',
        default=True,
        help="Les passagers peuvent descendre à cet arrêt",
    )

    @api.constrains('city_id', 'route_id')
    def _check_city_not_departure_arrival(self):
        """Vérifier que l'arrêt n'est pas la ville de départ ou d'arrivée"""
        for stop in self:
            if stop.city_id == stop.route_id.departure_city_id:
                raise ValidationError(_("L'arrêt ne peut pas être la ville de départ!"))
            if stop.city_id == stop.route_id.arrival_city_id:
                raise ValidationError(_("L'arrêt ne peut pas être la ville d'arrivée!"))
