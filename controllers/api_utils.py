# -*- coding: utf-8 -*-
"""
Utilitaires pour les APIs REST Mobile - Transport Interurbain
Version: 1.0.0

Ce module fournit les utilitaires communs pour:
- API Usagers (mobile_api_usager.py)
- API Agents d'embarquement (mobile_api_agent.py)
"""

import logging
import hashlib
import secrets
import functools
import time
from datetime import datetime, timedelta

from odoo import _, fields
from odoo.http import request, Response
import json

_logger = logging.getLogger(__name__)

# ==================== CONFIGURATION ====================

API_VERSION = "1.0.0"
TOKEN_EXPIRY_HOURS = 24 * 30  # 30 jours
MAX_LOGIN_ATTEMPTS = 5
RATE_LIMIT_WINDOW = 60  # secondes
RATE_LIMIT_MAX_REQUESTS = 100


# ==================== CODES D'ERREUR ====================

class APIErrorCodes:
    """Codes d'erreur standardisés pour l'API"""
    SUCCESS = 0
    INVALID_CREDENTIALS = 1001
    TOKEN_EXPIRED = 1002
    TOKEN_INVALID = 1003
    UNAUTHORIZED = 1004
    ACCOUNT_LOCKED = 1005
    ACCOUNT_INACTIVE = 1006
    
    VALIDATION_ERROR = 2001
    MISSING_PARAMETER = 2002
    INVALID_FORMAT = 2003
    
    RESOURCE_NOT_FOUND = 3001
    TRIP_NOT_AVAILABLE = 3002
    SEAT_NOT_AVAILABLE = 3003
    BOOKING_NOT_FOUND = 3004
    PASSENGER_NOT_FOUND = 3005
    
    PAYMENT_FAILED = 4001
    PAYMENT_PENDING = 4002
    INSUFFICIENT_FUNDS = 4003
    
    SERVER_ERROR = 5001
    DATABASE_ERROR = 5002
    EXTERNAL_SERVICE_ERROR = 5003
    
    RATE_LIMIT_EXCEEDED = 6001


# ==================== RÉPONSES API ====================

def api_response(data=None, message="Success", code=APIErrorCodes.SUCCESS):
    """Formater une réponse API réussie"""
    return {
        'success': True,
        'code': code,
        'message': message,
        'data': data or {},
        'timestamp': datetime.now().isoformat(),
        'api_version': API_VERSION,
    }


def api_error(message, code, details=None, http_status=400):
    """Formater une réponse API d'erreur"""
    return {
        'success': False,
        'code': code,
        'message': message,
        'details': details or {},
        'timestamp': datetime.now().isoformat(),
        'api_version': API_VERSION,
    }


def api_validation_error(errors):
    """Formater une erreur de validation"""
    return api_error(
        message="Erreur de validation des données",
        code=APIErrorCodes.VALIDATION_ERROR,
        details={'validation_errors': errors}
    )


# ==================== RATE LIMITING ====================

class RateLimiter:
    """Gestionnaire de limitation de requêtes"""
    
    def __init__(self):
        self._requests = {}
    
    def is_allowed(self, key, max_requests=RATE_LIMIT_MAX_REQUESTS, window=RATE_LIMIT_WINDOW):
        """Vérifier si une requête est autorisée"""
        now = time.time()
        
        if key not in self._requests:
            self._requests[key] = []
        
        # Nettoyer les anciennes requêtes
        self._requests[key] = [t for t in self._requests[key] if now - t < window]
        
        if len(self._requests[key]) >= max_requests:
            return False
        
        self._requests[key].append(now)
        return True
    
    def get_retry_after(self, key, window=RATE_LIMIT_WINDOW):
        """Obtenir le temps d'attente avant la prochaine requête autorisée"""
        if key not in self._requests or not self._requests[key]:
            return 0
        oldest = min(self._requests[key])
        return max(0, int(window - (time.time() - oldest)))


rate_limiter = RateLimiter()


# ==================== VALIDATION ====================

class InputValidator:
    """Validateur de données d'entrée"""
    
    @staticmethod
    def validate_phone(phone):
        """Valider un numéro de téléphone"""
        import re
        if not phone:
            return False, "Le numéro de téléphone est requis"
        
        cleaned = re.sub(r'[\s\-\.]', '', phone)
        if not re.match(r'^\+?[\d]{8,15}$', cleaned):
            return False, "Format de téléphone invalide"
        
        return True, cleaned
    
    @staticmethod
    def validate_email(email):
        """Valider une adresse email"""
        import re
        if not email:
            return True, email  # Email optionnel
        
        if not re.match(r'^[^\s@]+@[^\s@]+\.[^\s@]+$', email):
            return False, "Format d'email invalide"
        
        return True, email.lower().strip()
    
    @staticmethod
    def validate_date(date_str, format='%Y-%m-%d'):
        """Valider et parser une date"""
        if not date_str:
            return False, "Date requise"
        
        try:
            parsed = datetime.strptime(date_str, format).date()
            return True, parsed
        except ValueError:
            return False, f"Format de date invalide. Attendu: {format}"
    
    @staticmethod
    def validate_positive_int(value, field_name="valeur"):
        """Valider un entier positif"""
        try:
            val = int(value)
            if val <= 0:
                return False, f"{field_name} doit être positif"
            return True, val
        except (ValueError, TypeError):
            return False, f"{field_name} doit être un entier"
    
    @staticmethod
    def validate_pin(pin):
        """Valider un code PIN à 4 chiffres"""
        import re
        if not pin:
            return False, "Code PIN requis"
        
        if not re.match(r'^\d{4}$', str(pin)):
            return False, "Le code PIN doit contenir 4 chiffres"
        
        return True, str(pin)


# ==================== AUTHENTIFICATION ====================

def generate_api_token():
    """Générer un token API sécurisé"""
    return secrets.token_urlsafe(64)


def hash_token(token):
    """Hasher un token pour le stockage"""
    return hashlib.sha256(token.encode()).hexdigest()


def verify_passenger_token(token):
    """Vérifier un token passager et retourner le passager associé"""
    try:
        if not token:
            return False
        
        Passenger = request.env['transport.passenger'].sudo()
        passenger = Passenger.search([
            ('mobile_token', '=', token),
            ('mobile_token_expiry', '>', fields.Datetime.now()),
            ('active', '=', True),
        ], limit=1)
        
        return passenger if passenger else False
    except Exception as e:
        _logger.error(f"Erreur vérification token passager: {e}")
        return False


def verify_agent_token(token):
    """Vérifier un token agent et retourner l'utilisateur associé"""
    try:
        if not token:
            return False
        
        User = request.env['res.users'].sudo()
        user = User.search([
            ('transport_agent_token', '=', token),
            ('transport_agent_token_expiry', '>', fields.Datetime.now()),
            ('active', '=', True),
        ], limit=1)
        
        return user if user else False
    except Exception as e:
        _logger.error(f"Erreur vérification token agent: {e}")
        return False


# ==================== DÉCORATEURS ====================

def require_passenger_auth(func):
    """Décorateur pour exiger l'authentification passager"""
    @functools.wraps(func)
    def wrapper(self, *args, **kwargs):
        token = request.httprequest.headers.get('Authorization', '').replace('Bearer ', '')
        
        if not token:
            return api_error(
                message="Token d'authentification requis",
                code=APIErrorCodes.TOKEN_INVALID,
                http_status=401
            )
        
        passenger = verify_passenger_token(token)
        if not passenger:
            return api_error(
                message="Token invalide ou expiré",
                code=APIErrorCodes.TOKEN_EXPIRED,
                http_status=401
            )
        
        # Ajouter le passager au contexte
        kwargs['passenger'] = passenger
        return func(self, *args, **kwargs)
    
    return wrapper


def require_agent_auth(func):
    """Décorateur pour exiger l'authentification agent"""
    @functools.wraps(func)
    def wrapper(self, *args, **kwargs):
        token = request.httprequest.headers.get('Authorization', '').replace('Bearer ', '')
        
        if not token:
            return api_error(
                message="Token d'authentification requis",
                code=APIErrorCodes.TOKEN_INVALID,
                http_status=401
            )
        
        user = verify_agent_token(token)
        if not user:
            return api_error(
                message="Token invalide ou expiré",
                code=APIErrorCodes.TOKEN_EXPIRED,
                http_status=401
            )
        
        # Vérifier que l'utilisateur est bien un agent
        if not user.has_group('transport_interurbain.group_transport_agent'):
            return api_error(
                message="Accès non autorisé",
                code=APIErrorCodes.UNAUTHORIZED,
                http_status=403
            )
        
        # Ajouter l'utilisateur au contexte
        kwargs['agent_user'] = user
        return func(self, *args, **kwargs)
    
    return wrapper


def api_exception_handler(func):
    """Décorateur pour gérer les exceptions API"""
    @functools.wraps(func)
    def wrapper(self, *args, **kwargs):
        try:
            return func(self, *args, **kwargs)
        except Exception as e:
            _logger.exception(f"Erreur API non gérée: {e}")
            return api_error(
                message="Erreur serveur interne",
                code=APIErrorCodes.SERVER_ERROR,
                details={'error': str(e)},
                http_status=500
            )
    
    return wrapper


def rate_limit(max_requests=RATE_LIMIT_MAX_REQUESTS, window=RATE_LIMIT_WINDOW):
    """Décorateur pour limiter le nombre de requêtes"""
    def decorator(func):
        @functools.wraps(func)
        def wrapper(self, *args, **kwargs):
            client_ip = get_client_ip()
            key = f"{func.__name__}:{client_ip}"
            
            if not rate_limiter.is_allowed(key, max_requests, window):
                retry_after = rate_limiter.get_retry_after(key, window)
                return api_error(
                    message=f"Trop de requêtes. Réessayez dans {retry_after} secondes.",
                    code=APIErrorCodes.RATE_LIMIT_EXCEEDED,
                    details={'retry_after': retry_after},
                    http_status=429
                )
            
            return func(self, *args, **kwargs)
        return wrapper
    return decorator


# ==================== UTILITAIRES ====================

def get_client_ip():
    """Obtenir l'adresse IP du client"""
    if request.httprequest.environ.get('HTTP_X_FORWARDED_FOR'):
        return request.httprequest.environ['HTTP_X_FORWARDED_FOR'].split(',')[0].strip()
    return request.httprequest.environ.get('REMOTE_ADDR', 'unknown')


def format_currency(amount, currency_code='XOF'):
    """Formater un montant monétaire"""
    return f"{int(amount):,} {currency_code}".replace(',', ' ')


def format_datetime(dt, format='%d/%m/%Y %H:%M'):
    """Formater une date/heure"""
    if not dt:
        return None
    if isinstance(dt, str):
        dt = fields.Datetime.from_string(dt)
    return dt.strftime(format)


def format_date(d, format='%d/%m/%Y'):
    """Formater une date"""
    if not d:
        return None
    if isinstance(d, str):
        d = fields.Date.from_string(d)
    return d.strftime(format)


def log_api_call(endpoint, method, status, duration=None, details=None):
    """Logger un appel API"""
    _logger.info(
        f"API Call: {method} {endpoint} - Status: {status}" +
        (f" - Duration: {duration}ms" if duration else "") +
        (f" - {details}" if details else "")
    )
