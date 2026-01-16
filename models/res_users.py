# -*- coding: utf-8 -*-

from odoo import api, fields, models


class ResUsers(models.Model):
    """Extension du modèle res.users pour l'authentification mobile des agents"""
    _inherit = 'res.users'

    # Token pour l'API mobile des agents d'embarquement
    transport_agent_token = fields.Char(
        string='Token Agent Transport',
        copy=False,
        index=True,
        help="Token d'authentification pour l'application mobile agent",
    )
    transport_agent_token_expiry = fields.Datetime(
        string='Expiration Token Agent',
        help="Date et heure d'expiration du token agent",
    )
    
    # Association à une compagnie de transport
    transport_company_ids = fields.Many2many(
        'transport.company',
        'transport_company_user_rel',
        'user_id',
        'company_id',
        string='Compagnies de transport',
        help="Compagnies de transport auxquelles l'agent est associé",
    )

    def _invalidate_transport_token(self):
        """Invalider le token de l'agent"""
        self.write({
            'transport_agent_token': False,
            'transport_agent_token_expiry': False,
        })
