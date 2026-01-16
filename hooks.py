# -*- coding: utf-8 -*-

from datetime import datetime, timedelta
import logging

_logger = logging.getLogger(__name__)


def post_init_hook(env):
    """
    Hook exécuté après l'installation du module.
    Génère des voyages de démonstration avec des dates dynamiques.
    """
    _logger.info("Transport Interurbain: Génération des données de démonstration...")
    
    # Récupérer les compagnies
    Company = env['transport.company']
    Trip = env['transport.trip']
    Route = env['transport.route']
    
    companies = Company.search([])
    routes = Route.search([('state', '=', 'active')])
    
    if not companies or not routes:
        _logger.info("Pas de compagnies ou routes trouvées, skip création voyages démo")
        return
    
    # Date de base: aujourd'hui
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    
    # Créer des voyages pour les 7 prochains jours
    trips_created = 0
    
    # Mapping compagnie -> bus
    company_buses = {}
    for company in companies:
        buses = company.bus_ids.filtered(lambda b: b.state == 'available')
        if buses:
            company_buses[company.id] = buses
    
    # Horaires de départ standards
    departure_times = [
        (6, 0),   # 6h00
        (7, 30),  # 7h30
        (9, 0),   # 9h00
        (11, 0),  # 11h00
        (13, 30), # 13h30
        (15, 0),  # 15h00
        (17, 0),  # 17h00
        (19, 30), # 19h30
    ]
    
    # Lieux de rassemblement par compagnie
    meeting_points = {
        'UTB': 'Gare Routière d\'Adjamé - Quai UTB',
        'ATT': 'Gare Routière d\'Adjamé - Zone B, Quai ATT',
        'CTV': 'Gare Routière Yopougon - Quai CTV',
        'TCV': 'Gare Routière de Marcory - TCV Express',
        'STS': 'Gare Routière de Treichville - Quai STS',
    }
    
    for day_offset in range(7):
        current_date = today + timedelta(days=day_offset)
        
        for company in companies:
            if company.id not in company_buses:
                continue
            
            buses = company_buses[company.id]
            
            # Sélectionner 3-5 routes pour chaque compagnie
            company_routes = routes[:min(5, len(routes))]
            
            for i, route in enumerate(company_routes):
                # Alterner les horaires selon le jour et la route
                time_index = (day_offset + i) % len(departure_times)
                hour, minute = departure_times[time_index]
                
                departure_dt = current_date.replace(hour=hour, minute=minute)
                
                # Sauter si le voyage est dans le passé
                if departure_dt < datetime.now():
                    continue
                
                # Sélectionner un bus
                bus = buses[i % len(buses)]
                
                # Prix avec variation selon compagnie et type de bus
                base_price = route.base_price or 5000
                price_multiplier = 1.0
                if 'VIP' in bus.name or 'Luxe' in bus.name:
                    price_multiplier = 1.3
                elif 'Express' in bus.name:
                    price_multiplier = 1.2
                
                price = int(base_price * price_multiplier)
                vip_price = int(price * 1.5) if bus.has_vip_seats else 0
                child_price = int(price * 0.6)
                
                # Lieu de rassemblement
                meeting_point = meeting_points.get(company.code, 'Gare Routière')
                
                # Créer le voyage
                try:
                    trip = Trip.create({
                        'company_id': company.id,
                        'route_id': route.id,
                        'bus_id': bus.id,
                        'departure_datetime': departure_dt,
                        'meeting_point': meeting_point,
                        'meeting_point_address': f"{meeting_point}, Abidjan, Côte d'Ivoire",
                        'meeting_time_before': 30,
                        'price': price,
                        'vip_price': vip_price,
                        'child_price': child_price,
                        'luggage_included_kg': bus.luggage_per_passenger_kg,
                        'extra_luggage_price': bus.extra_luggage_price_kg,
                        'driver_name': f"Conducteur {company.code}-{i+1}",
                        'driver_phone': f"+225 07 0{company.id} {day_offset}{i} {time_index}0 00",
                        'state': 'scheduled',
                        'is_published': True,
                        'passenger_info': f"""
                            <p><strong>Informations voyage {company.name}</strong></p>
                            <ul>
                                <li>Présentez-vous 30 minutes avant le départ</li>
                                <li>Munissez-vous d'une pièce d'identité valide</li>
                                <li>Franchise bagage: {bus.luggage_per_passenger_kg}kg inclus</li>
                            </ul>
                        """,
                    })
                    trips_created += 1
                except Exception as e:
                    _logger.warning("Erreur création voyage démo: %s", str(e))
    
    _logger.info("Transport Interurbain: %d voyages de démonstration créés", trips_created)


def uninstall_hook(env):
    """Hook exécuté lors de la désinstallation du module."""
    _logger.info("Transport Interurbain: Nettoyage des données...")
