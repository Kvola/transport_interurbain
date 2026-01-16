# -*- coding: utf-8 -*-

from odoo import api, fields, models, _
from odoo.exceptions import UserError
import uuid
import hashlib
import hmac
import json
import requests
from datetime import datetime


class TransportPayment(models.Model):
    """Paiement pour une réservation"""
    _name = 'transport.payment'
    _description = 'Paiement'
    _inherit = ['mail.thread']
    _order = 'create_date desc'

    name = fields.Char(
        string='Référence',
        required=True,
        copy=False,
        readonly=True,
        default='/',
        index=True,
    )
    booking_id = fields.Many2one(
        'transport.booking',
        string='Réservation',
        required=True,
        ondelete='cascade',
        tracking=True,
    )
    amount = fields.Monetary(
        string='Montant',
        currency_field='currency_id',
        required=True,
        tracking=True,
    )
    payment_method = fields.Selection([
        ('cash', 'Espèces'),
        ('wave', 'Wave'),
        ('orange_money', 'Orange Money'),
        ('mtn_money', 'MTN Money'),
        ('moov_money', 'Moov Money'),
        ('card', 'Carte bancaire'),
    ], string='Mode de paiement', required=True, tracking=True)
    
    # Informations de transaction
    transaction_id = fields.Char(
        string='ID Transaction',
        index=True,
    )
    external_reference = fields.Char(
        string='Référence externe',
    )
    payment_phone = fields.Char(
        string='Téléphone paiement',
    )
    payment_date = fields.Datetime(
        string='Date du paiement',
        default=fields.Datetime.now,
    )
    
    # Wave spécifique
    wave_checkout_id = fields.Char(
        string='Wave Checkout ID',
    )
    wave_payment_url = fields.Char(
        string='URL de paiement Wave',
    )
    wave_response = fields.Text(
        string='Réponse Wave',
    )
    
    # État
    state = fields.Selection([
        ('pending', 'En attente'),
        ('processing', 'En cours'),
        ('completed', 'Complété'),
        ('failed', 'Échoué'),
        ('refunded', 'Remboursé'),
        ('cancelled', 'Annulé'),
    ], string='État', default='pending', tracking=True, index=True)
    
    error_message = fields.Text(
        string='Message d\'erreur',
    )
    
    currency_id = fields.Many2one(
        related='booking_id.currency_id',
    )
    company_id = fields.Many2one(
        related='booking_id.company_id',
        store=True,
    )

    _sql_constraints = [
        ('name_uniq', 'UNIQUE(name)', 'La référence du paiement doit être unique!'),
    ]

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if vals.get('name', '/') == '/':
                vals['name'] = self.env['ir.sequence'].next_by_code('transport.payment') or '/'
        return super().create(vals_list)

    def action_process_wave_payment(self):
        """Initier un paiement Wave"""
        self.ensure_one()
        
        if self.payment_method != 'wave':
            raise UserError(_("Cette méthode est réservée aux paiements Wave!"))
        
        company = self.company_id
        if not company.wave_merchant_id or not company.wave_api_key:
            raise UserError(_("La compagnie n'a pas configuré Wave!"))
        
        # Préparer les données pour Wave
        checkout_data = {
            'amount': str(int(self.amount)),
            'currency': 'XOF',
            'merchant_id': company.wave_merchant_id,
            'payment_id': self.name,
            'client_reference': self.booking_id.name,
            'success_url': f'/transport/payment/success/{self.id}',
            'error_url': f'/transport/payment/error/{self.id}',
            'webhook_url': f'/transport/payment/webhook/{self.id}',
        }
        
        try:
            # Appel API Wave (à adapter selon la documentation Wave)
            headers = {
                'Authorization': f'Bearer {company.wave_api_key}',
                'Content-Type': 'application/json',
            }
            
            response = requests.post(
                'https://api.wave.com/v1/checkout/sessions',
                json=checkout_data,
                headers=headers,
                timeout=30,
            )
            
            if response.status_code == 200:
                result = response.json()
                self.write({
                    'state': 'processing',
                    'wave_checkout_id': result.get('id'),
                    'wave_payment_url': result.get('wave_launch_url'),
                    'wave_response': json.dumps(result),
                })
                return {
                    'type': 'ir.actions.act_url',
                    'url': result.get('wave_launch_url'),
                    'target': 'new',
                }
            else:
                self.write({
                    'state': 'failed',
                    'error_message': f"Erreur Wave: {response.text}",
                })
                raise UserError(_("Erreur lors de l'initiation du paiement Wave"))
                
        except requests.exceptions.RequestException as e:
            self.write({
                'state': 'failed',
                'error_message': str(e),
            })
            raise UserError(_("Erreur de connexion au service Wave"))

    def action_confirm_cash_payment(self):
        """Confirmer un paiement en espèces"""
        self.ensure_one()
        
        if self.payment_method != 'cash':
            raise UserError(_("Cette méthode est réservée aux paiements en espèces!"))
        
        self.write({
            'state': 'completed',
            'payment_date': fields.Datetime.now(),
        })
        
        # Mettre à jour la réservation
        self._update_booking_payment()

    def action_complete_payment(self):
        """Marquer le paiement comme complété"""
        for payment in self:
            if payment.state != 'processing':
                raise UserError(_("Seuls les paiements en cours peuvent être complétés!"))
            
            payment.write({
                'state': 'completed',
                'payment_date': fields.Datetime.now(),
            })
            payment._update_booking_payment()

    def action_fail_payment(self):
        """Marquer le paiement comme échoué"""
        self.write({'state': 'failed'})

    def action_refund(self):
        """Rembourser le paiement"""
        for payment in self:
            if payment.state != 'completed':
                raise UserError(_("Seuls les paiements complétés peuvent être remboursés!"))
            
            # TODO: Implémenter le remboursement Wave
            payment.write({'state': 'refunded'})

    def _update_booking_payment(self):
        """Mettre à jour le montant payé sur la réservation"""
        self.ensure_one()
        booking = self.booking_id
        total_paid = sum(
            booking.payment_ids.filtered(lambda p: p.state == 'completed').mapped('amount')
        )
        booking.write({
            'amount_paid': total_paid,
            'payment_method': self.payment_method,
            'payment_reference': self.transaction_id or self.name,
            'payment_date': self.payment_date,
        })
        
        # Confirmer automatiquement si paiement complet
        if booking.amount_due <= 0 and booking.state in ['draft', 'reserved']:
            booking.action_confirm()

    @api.model
    def process_wave_webhook(self, payment_id, data):
        """Traiter le webhook Wave"""
        payment = self.browse(payment_id)
        if not payment.exists():
            return False
        
        event_type = data.get('type')
        if event_type == 'checkout.session.completed':
            payment.write({
                'state': 'completed',
                'transaction_id': data.get('transaction_id'),
                'wave_response': json.dumps(data),
                'payment_date': fields.Datetime.now(),
            })
            payment._update_booking_payment()
        elif event_type == 'checkout.session.failed':
            payment.write({
                'state': 'failed',
                'error_message': data.get('error_message'),
                'wave_response': json.dumps(data),
            })
        
        return True
