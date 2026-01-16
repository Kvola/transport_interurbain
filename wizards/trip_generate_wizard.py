# -*- coding: utf-8 -*-

from odoo import api, fields, models, _
from odoo.exceptions import UserError
from datetime import timedelta


class TransportTripGenerateWizard(models.TransientModel):
    """Wizard pour générer des voyages à partir d'un programme"""
    _name = 'transport.trip.generate.wizard'
    _description = 'Générer des voyages'

    schedule_id = fields.Many2one(
        'transport.trip.schedule',
        string='Programme',
        required=True,
        readonly=True,
    )
    transport_company_id = fields.Many2one(
        related='schedule_id.transport_company_id',
        string='Compagnie',
    )
    route_id = fields.Many2one(
        related='schedule_id.route_id',
        string='Itinéraire',
    )
    
    date_from = fields.Date(
        string='Date de début',
        required=True,
        default=fields.Date.today,
    )
    date_to = fields.Date(
        string='Date de fin',
        required=True,
    )
    
    skip_existing = fields.Boolean(
        string='Ignorer les créneaux existants',
        default=True,
        help="Si coché, ne pas créer de voyage si un existe déjà pour ce créneau horaire",
    )
    
    # Informations calculées
    estimated_trips = fields.Integer(
        string='Voyages estimés',
        compute='_compute_estimated_trips',
    )
    days_count = fields.Integer(
        string='Nombre de jours',
        compute='_compute_estimated_trips',
    )
    operating_days_display = fields.Char(
        string='Jours d\'opération',
        compute='_compute_operating_days_display',
    )

    @api.constrains('date_from', 'date_to')
    def _check_dates(self):
        for wizard in self:
            if wizard.date_to < wizard.date_from:
                raise UserError(_("La date de fin doit être postérieure à la date de début!"))
            if wizard.date_to > wizard.date_from + timedelta(days=365):
                raise UserError(_("La période de génération ne peut pas dépasser 1 an!"))

    @api.depends('date_from', 'date_to', 'schedule_id')
    def _compute_estimated_trips(self):
        for wizard in self:
            if not wizard.schedule_id or not wizard.date_from or not wizard.date_to:
                wizard.estimated_trips = 0
                wizard.days_count = 0
                continue
            
            operating_days = wizard.schedule_id._get_operating_days()
            lines_count = len(wizard.schedule_id.line_ids)
            
            days = 0
            current = wizard.date_from
            while current <= wizard.date_to:
                if current.weekday() in operating_days:
                    days += 1
                current += timedelta(days=1)
            
            wizard.days_count = days
            wizard.estimated_trips = days * lines_count

    @api.depends('schedule_id')
    def _compute_operating_days_display(self):
        day_names = {
            0: 'Lun', 1: 'Mar', 2: 'Mer', 3: 'Jeu', 4: 'Ven', 5: 'Sam', 6: 'Dim'
        }
        for wizard in self:
            if wizard.schedule_id:
                days = wizard.schedule_id._get_operating_days()
                wizard.operating_days_display = ', '.join([day_names[d] for d in sorted(days)])
            else:
                wizard.operating_days_display = ''

    def action_generate(self):
        """Lancer la génération des voyages"""
        self.ensure_one()
        
        if self.schedule_id.state != 'active':
            raise UserError(_("Le programme doit être actif pour générer des voyages!"))
        
        created_trips = self.schedule_id.generate_trips(
            self.date_from,
            self.date_to,
            skip_existing=self.skip_existing,
        )
        
        # Afficher le résultat
        if created_trips:
            return {
                'type': 'ir.actions.act_window',
                'name': _('Voyages générés (%d)') % len(created_trips),
                'res_model': 'transport.trip',
                'view_mode': 'tree,form,calendar',
                'domain': [('id', 'in', created_trips.ids)],
                'context': {'create': False},
            }
        else:
            return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'title': _('Génération terminée'),
                    'message': _('Aucun nouveau voyage créé. Tous les créneaux existent déjà.'),
                    'type': 'warning',
                    'sticky': False,
                },
            }

    def action_preview(self):
        """Aperçu des voyages qui seront générés"""
        self.ensure_one()
        
        operating_days = self.schedule_id._get_operating_days()
        day_names = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche']
        
        preview_lines = []
        current = self.date_from
        count = 0
        max_preview = 20  # Limiter l'aperçu
        
        while current <= self.date_to and count < max_preview:
            if current.weekday() in operating_days:
                for line in self.schedule_id.line_ids:
                    hours = int(line.departure_hour)
                    minutes = int((line.departure_hour % 1) * 60)
                    preview_lines.append({
                        'date': current.strftime('%d/%m/%Y'),
                        'day': day_names[current.weekday()],
                        'time': f"{hours:02d}:{minutes:02d}",
                        'label': line.label or '',
                    })
                    count += 1
            current += timedelta(days=1)
        
        # Retourner une notification avec l'aperçu
        message = "Aperçu des %d premiers voyages:\n" % min(count, max_preview)
        for p in preview_lines[:10]:
            message += f"\n• {p['day']} {p['date']} à {p['time']}"
        if count > 10:
            message += f"\n... et {count - 10} autres"
        
        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': _('Aperçu de génération'),
                'message': message,
                'type': 'info',
                'sticky': True,
            },
        }
