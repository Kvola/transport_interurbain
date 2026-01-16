# -*- coding: utf-8 -*-

from odoo import api, fields, models, _
from odoo.exceptions import ValidationError


class TransportCompany(models.Model):
    """Compagnie de transport"""
    _name = 'transport.company'
    _description = 'Compagnie de transport'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _order = 'name'

    name = fields.Char(
        string='Nom de la compagnie',
        required=True,
        tracking=True,
        index=True,
    )
    code = fields.Char(
        string='Code',
        required=True,
        copy=False,
        readonly=True,
        default='/',
        index=True,
    )
    partner_id = fields.Many2one(
        'res.partner',
        string='Contact associé',
        tracking=True,
    )
    logo = fields.Binary(
        string='Logo',
        attachment=True,
    )
    phone = fields.Char(
        string='Téléphone',
        tracking=True,
    )
    email = fields.Char(
        string='Email',
        tracking=True,
    )
    website = fields.Char(
        string='Site web',
    )
    address = fields.Text(
        string='Adresse',
    )
    city_id = fields.Many2one(
        'transport.city',
        string='Ville du siège',
    )
    description = fields.Html(
        string='Description',
    )
    
    # Configuration
    reservation_duration_hours = fields.Integer(
        string='Durée de réservation (heures)',
        default=24,
        help="Durée maximum de réservation avant annulation automatique (max 24h)",
    )
    reservation_fee = fields.Monetary(
        string='Frais de réservation',
        currency_field='currency_id',
        help="Frais facturés pour une réservation temporaire",
    )
    allow_online_payment = fields.Boolean(
        string='Paiement en ligne',
        default=True,
        help="Autoriser le paiement en ligne (Wave)",
    )
    wave_merchant_id = fields.Char(
        string='Wave Merchant ID',
        help="Identifiant marchand Wave pour les paiements",
    )
    wave_api_key = fields.Char(
        string='Clé API Wave',
        groups='transport_interurbain.group_transport_admin',
    )
    
    # Relations
    bus_ids = fields.One2many(
        'transport.bus',
        'company_id',
        string='Flotte de bus',
    )
    trip_ids = fields.One2many(
        'transport.trip',
        'company_id',
        string='Voyages',
    )
    manager_ids = fields.Many2many(
        'res.users',
        'transport_company_manager_rel',
        'company_id',
        'user_id',
        string='Responsables',
        help="Utilisateurs autorisés à gérer cette compagnie",
    )
    
    # Statistiques
    bus_count = fields.Integer(
        compute='_compute_counts',
        string='Nombre de bus',
    )
    trip_count = fields.Integer(
        compute='_compute_counts',
        string='Nombre de voyages',
    )
    active_trip_count = fields.Integer(
        compute='_compute_counts',
        string='Voyages actifs',
    )
    total_bookings = fields.Integer(
        compute='_compute_counts',
        string='Total réservations',
    )
    
    currency_id = fields.Many2one(
        'res.currency',
        string='Devise',
        default=lambda self: self.env['res.currency'].search([('name', '=', 'XOF')], limit=1),
    )
    active = fields.Boolean(
        default=True,
    )
    state = fields.Selection([
        ('pending', 'En attente'),
        ('active', 'Active'),
        ('suspended', 'Suspendue'),
    ], string='État', default='pending', tracking=True)
    
    # Rating
    rating = fields.Float(
        string='Note moyenne',
        compute='_compute_rating',
        digits=(2, 1),
    )
    rating_count = fields.Integer(
        string='Nombre d\'avis',
        compute='_compute_rating',
    )

    _sql_constraints = [
        ('code_uniq', 'UNIQUE(code)', 'Le code de la compagnie doit être unique!'),
        ('reservation_duration_max', 'CHECK(reservation_duration_hours <= 24)',
         'La durée de réservation ne peut pas dépasser 24 heures!'),
    ]

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if vals.get('code', '/') == '/':
                vals['code'] = self.env['ir.sequence'].next_by_code('transport.company') or '/'
        return super().create(vals_list)

    @api.constrains('reservation_duration_hours')
    def _check_reservation_duration(self):
        for company in self:
            if company.reservation_duration_hours > 24:
                raise ValidationError(_("La durée de réservation ne peut pas dépasser 24 heures!"))
            if company.reservation_duration_hours < 1:
                raise ValidationError(_("La durée de réservation doit être d'au moins 1 heure!"))

    def _compute_counts(self):
        for company in self:
            company.bus_count = len(company.bus_ids)
            company.trip_count = len(company.trip_ids)
            company.active_trip_count = self.env['transport.trip'].search_count([
                ('company_id', '=', company.id),
                ('state', '=', 'scheduled'),
            ])
            company.total_bookings = self.env['transport.booking'].search_count([
                ('trip_id.company_id', '=', company.id),
            ])

    def _compute_rating(self):
        for company in self:
            ratings = self.env['transport.booking'].search([
                ('trip_id.company_id', '=', company.id),
                ('rating', '>', 0),
            ])
            if ratings:
                company.rating = sum(ratings.mapped('rating')) / len(ratings)
                company.rating_count = len(ratings)
            else:
                company.rating = 0
                company.rating_count = 0

    def action_activate(self):
        """Activer la compagnie"""
        self.write({'state': 'active'})

    def action_suspend(self):
        """Suspendre la compagnie"""
        self.write({'state': 'suspended'})

    def action_view_buses(self):
        """Voir la flotte de bus"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': _('Flotte - %s') % self.name,
            'res_model': 'transport.bus',
            'view_mode': 'tree,form',
            'domain': [('company_id', '=', self.id)],
            'context': {'default_company_id': self.id},
        }

    def action_view_trips(self):
        """Voir les voyages"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': _('Voyages - %s') % self.name,
            'res_model': 'transport.trip',
            'view_mode': 'tree,form,calendar',
            'domain': [('company_id', '=', self.id)],
            'context': {'default_company_id': self.id},
        }

    def action_view_bookings(self):
        """Voir les réservations"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': _('Réservations - %s') % self.name,
            'res_model': 'transport.booking',
            'view_mode': 'tree,form',
            'domain': [('trip_id.company_id', '=', self.id)],
        }

    def action_open_dashboard(self):
        """Ouvrir le tableau de bord de la compagnie"""
        self.ensure_one()
        return {
            'type': 'ir.actions.client',
            'tag': 'transport_company_dashboard',
            'params': {'company_id': self.id},
            'name': _('Tableau de bord - %s') % self.name,
        }
