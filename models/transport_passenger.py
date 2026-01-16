# -*- coding: utf-8 -*-

from odoo import api, fields, models, _
import uuid
import qrcode
import base64
from io import BytesIO


class TransportPassenger(models.Model):
    """Passager enregistré"""
    _name = 'transport.passenger'
    _description = 'Passager'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _order = 'name'

    name = fields.Char(
        string='Nom complet',
        required=True,
        tracking=True,
        index=True,
    )
    partner_id = fields.Many2one(
        'res.partner',
        string='Contact associé',
        tracking=True,
    )
    phone = fields.Char(
        string='Téléphone',
        tracking=True,
    )
    email = fields.Char(
        string='Email',
    )
    id_type = fields.Selection([
        ('cni', 'CNI'),
        ('passport', 'Passeport'),
        ('permis', 'Permis de conduire'),
        ('birth_cert', 'Acte de naissance'),
        ('other', 'Autre'),
    ], string='Type de pièce d\'identité')
    id_number = fields.Char(
        string='Numéro de pièce',
    )
    date_of_birth = fields.Date(
        string='Date de naissance',
    )
    gender = fields.Selection([
        ('male', 'Homme'),
        ('female', 'Femme'),
    ], string='Genre')
    
    # Préférences
    preferred_seat_position = fields.Selection([
        ('window', 'Fenêtre'),
        ('aisle', 'Couloir'),
        ('any', 'Peu importe'),
    ], string='Position préférée', default='any')
    special_needs = fields.Text(
        string='Besoins spéciaux',
    )
    is_minor = fields.Boolean(
        string='Mineur',
        compute='_compute_is_minor',
        store=True,
    )
    guardian_name = fields.Char(
        string='Nom du tuteur',
        help="Obligatoire pour les mineurs non accompagnés",
    )
    guardian_phone = fields.Char(
        string='Téléphone du tuteur',
    )
    
    # Statistiques
    booking_count = fields.Integer(
        string='Nombre de voyages',
        compute='_compute_booking_count',
    )
    total_spent = fields.Monetary(
        string='Total dépensé',
        compute='_compute_booking_count',
        currency_field='currency_id',
    )
    last_trip_date = fields.Datetime(
        string='Dernier voyage',
        compute='_compute_booking_count',
    )
    
    # Fidélité
    loyalty_points = fields.Integer(
        string='Points de fidélité',
        default=0,
    )
    loyalty_level = fields.Selection([
        ('bronze', 'Bronze'),
        ('silver', 'Argent'),
        ('gold', 'Or'),
        ('platinum', 'Platine'),
    ], string='Niveau fidélité', compute='_compute_loyalty_level', store=True)
    
    currency_id = fields.Many2one(
        'res.currency',
        default=lambda self: self.env['res.currency'].search([('name', '=', 'XOF')], limit=1),
    )
    active = fields.Boolean(
        default=True,
    )
    notes = fields.Text(
        string='Notes',
    )
    
    # QR Code unique permanent pour identification
    unique_token = fields.Char(
        string='Token unique',
        copy=False,
        readonly=True,
        index=True,
        help="Token unique pour identifier le passager",
    )
    unique_qr_code = fields.Binary(
        string='QR Code unique',
        compute='_compute_unique_qr_code',
        store=True,
        help="QR Code unique pour identification du passager",
    )
    pin_code = fields.Char(
        string='Code PIN',
        help="Code PIN à 4 chiffres pour sécuriser l'accès mobile",
    )
    
    # Authentification mobile
    mobile_token = fields.Char(
        string='Token mobile',
        copy=False,
        index=True,
    )
    mobile_token_expiry = fields.Datetime(
        string='Expiration token mobile',
    )

    @api.depends('date_of_birth')
    def _compute_is_minor(self):
        today = fields.Date.today()
        for passenger in self:
            if passenger.date_of_birth:
                age = (today - passenger.date_of_birth).days // 365
                passenger.is_minor = age < 18
            else:
                passenger.is_minor = False

    @api.depends('unique_token')
    def _compute_unique_qr_code(self):
        """Générer le QR Code unique pour identification du passager"""
        for passenger in self:
            if passenger.unique_token:
                qr_data = f"PASSENGER:{passenger.unique_token}"
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
                passenger.unique_qr_code = base64.b64encode(buffer.getvalue())
            else:
                passenger.unique_qr_code = False

    @api.model_create_multi
    def create(self, vals_list):
        """Générer automatiquement le token unique à la création"""
        for vals in vals_list:
            if not vals.get('unique_token'):
                vals['unique_token'] = str(uuid.uuid4())
        return super().create(vals_list)

    def _generate_pin_code(self):
        """Générer un code PIN à 4 chiffres"""
        import random
        self.ensure_one()
        self.pin_code = str(random.randint(1000, 9999))
        return self.pin_code

    def _compute_booking_count(self):
        for passenger in self:
            bookings = self.env['transport.booking'].search([
                ('passenger_id', '=', passenger.id),
                ('state', 'in', ['confirmed', 'completed']),
            ])
            passenger.booking_count = len(bookings)
            passenger.total_spent = sum(bookings.mapped('total_amount'))
            last_booking = bookings.sorted('departure_datetime', reverse=True)[:1]
            passenger.last_trip_date = last_booking.departure_datetime if last_booking else False

    @api.depends('loyalty_points')
    def _compute_loyalty_level(self):
        for passenger in self:
            if passenger.loyalty_points >= 10000:
                passenger.loyalty_level = 'platinum'
            elif passenger.loyalty_points >= 5000:
                passenger.loyalty_level = 'gold'
            elif passenger.loyalty_points >= 2000:
                passenger.loyalty_level = 'silver'
            else:
                passenger.loyalty_level = 'bronze'

    def add_loyalty_points(self, points):
        """Ajouter des points de fidélité"""
        for passenger in self:
            passenger.loyalty_points += points

    def action_view_bookings(self):
        """Voir les réservations du passager"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': _('Réservations - %s') % self.name,
            'res_model': 'transport.booking',
            'view_mode': 'tree,form',
            'domain': [('passenger_id', '=', self.id)],
            'context': {'default_passenger_id': self.id},
        }
