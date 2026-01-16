# -*- coding: utf-8 -*-

from odoo import api, fields, models, _
from odoo.exceptions import ValidationError


class TransportCity(models.Model):
    """Modèle pour les villes/arrêts de transport"""
    _name = 'transport.city'
    _description = 'Ville / Arrêt'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _order = 'name'

    name = fields.Char(
        string='Nom de la ville',
        required=True,
        tracking=True,
        index=True,
    )
    code = fields.Char(
        string='Code',
        required=True,
        tracking=True,
        index=True,
    )
    region = fields.Char(
        string='Région',
        tracking=True,
    )
    country_id = fields.Many2one(
        'res.country',
        string='Pays',
        default=lambda self: self.env.ref('base.ci', raise_if_not_found=False),
        tracking=True,
    )
    is_major_city = fields.Boolean(
        string='Ville principale',
        default=False,
        help="Cocher si c'est une grande ville (point de départ/arrivée principal)",
    )
    latitude = fields.Float(
        string='Latitude',
        digits=(10, 7),
    )
    longitude = fields.Float(
        string='Longitude',
        digits=(10, 7),
    )
    description = fields.Text(
        string='Description',
    )
    active = fields.Boolean(
        default=True,
    )
    
    # Stats
    departure_count = fields.Integer(
        string='Nb. départs',
        compute='_compute_trip_counts',
    )
    arrival_count = fields.Integer(
        string='Nb. arrivées',
        compute='_compute_trip_counts',
    )

    _sql_constraints = [
        ('code_uniq', 'UNIQUE(code)', 'Le code de la ville doit être unique!'),
        ('name_uniq', 'UNIQUE(name)', 'Le nom de la ville doit être unique!'),
    ]

    @api.depends('name')
    def _compute_trip_counts(self):
        """Calcule le nombre de voyages en départ/arrivée de cette ville"""
        for city in self:
            city.departure_count = self.env['transport.trip'].search_count([
                ('route_id.departure_city_id', '=', city.id),
                ('state', 'not in', ['cancelled']),
            ])
            city.arrival_count = self.env['transport.trip'].search_count([
                ('route_id.arrival_city_id', '=', city.id),
                ('state', 'not in', ['cancelled']),
            ])

    def action_view_departures(self):
        """Voir les voyages partant de cette ville"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': _('Voyages au départ de %s') % self.name,
            'res_model': 'transport.trip',
            'view_mode': 'tree,form,calendar',
            'domain': [('route_id.departure_city_id', '=', self.id)],
            'context': {'default_departure_city_id': self.id},
        }

    def action_view_arrivals(self):
        """Voir les voyages arrivant à cette ville"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': _('Voyages à destination de %s') % self.name,
            'res_model': 'transport.trip',
            'view_mode': 'tree,form,calendar',
            'domain': [('route_id.arrival_city_id', '=', self.id)],
        }
