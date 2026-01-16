# -*- coding: utf-8 -*-

from odoo import api, fields, models


class ResPartner(models.Model):
    """Extension du modèle partenaire pour le transport"""
    _inherit = 'res.partner'

    is_transport_customer = fields.Boolean(
        string='Client transport',
        default=False,
    )
    transport_booking_ids = fields.One2many(
        'transport.booking',
        'partner_id',
        string='Réservations transport',
    )
    transport_booking_count = fields.Integer(
        string='Nombre de réservations',
        compute='_compute_transport_booking_count',
    )
    transport_currency_id = fields.Many2one(
        'res.currency',
        string='Devise transport',
        default=lambda self: self.env['res.currency'].search([('name', '=', 'XOF')], limit=1),
    )
    total_transport_spent = fields.Monetary(
        string='Total dépensé transport',
        compute='_compute_transport_booking_count',
        currency_field='transport_currency_id',
    )
    favorite_route_ids = fields.Many2many(
        'transport.route',
        'partner_favorite_route_rel',
        'partner_id',
        'route_id',
        string='Itinéraires favoris',
    )
    transport_loyalty_points = fields.Integer(
        string='Points fidélité transport',
        default=0,
    )

    def _compute_transport_booking_count(self):
        for partner in self:
            bookings = partner.transport_booking_ids.filtered(
                lambda b: b.state in ['confirmed', 'completed']
            )
            partner.transport_booking_count = len(bookings)
            partner.total_transport_spent = sum(bookings.mapped('total_amount'))

    def action_view_transport_bookings(self):
        """Voir les réservations de transport"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': 'Réservations transport',
            'res_model': 'transport.booking',
            'view_mode': 'tree,form',
            'domain': [('partner_id', '=', self.id)],
            'context': {'default_partner_id': self.id},
        }
