# -*- coding: utf-8 -*-

from odoo import api, fields, models


class ResConfigSettings(models.TransientModel):
    _inherit = 'res.config.settings'

    transport_default_booking_quota = fields.Integer(
        string='Quota de réservation par défaut',
        default=0,
        config_parameter='transport_interurbain.default_booking_quota',
        help="Quota de réservations par défaut pour les nouveaux voyages. "
             "0 signifie pas de limite (utilise la capacité du bus).",
    )

    @api.model
    def get_values(self):
        res = super().get_values()
        res['transport_default_booking_quota'] = int(
            self.env['ir.config_parameter'].sudo().get_param(
                'transport_interurbain.default_booking_quota', default='0'
            )
        )
        return res

    def set_values(self):
        super().set_values()
        self.env['ir.config_parameter'].sudo().set_param(
            'transport_interurbain.default_booking_quota',
            self.transport_default_booking_quota
        )
