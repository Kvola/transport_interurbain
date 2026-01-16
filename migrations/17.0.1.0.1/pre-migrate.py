# -*- coding: utf-8 -*-
"""
Migration to rename company_id to transport_company_id
This avoids conflict with Odoo's standard company_id field that references res.company
"""

import logging

_logger = logging.getLogger(__name__)


def migrate(cr, version):
    """Rename company_id to transport_company_id in all affected tables"""
    if not version:
        return
    
    _logger.info("Renaming company_id to transport_company_id in transport module tables...")
    
    tables_to_migrate = [
        'transport_trip',
        'transport_bus',
        'transport_trip_schedule',
        'transport_booking',
        'transport_payment',
    ]
    
    for table in tables_to_migrate:
        # Check if the table exists
        cr.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = %s
            )
        """, (table,))
        
        if not cr.fetchone()[0]:
            _logger.info(f"Table {table} does not exist, skipping...")
            continue
        
        # Check if old column exists
        cr.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.columns 
                WHERE table_name = %s AND column_name = 'company_id'
            )
        """, (table,))
        
        if not cr.fetchone()[0]:
            _logger.info(f"Column company_id does not exist in {table}, skipping...")
            continue
        
        # Check if new column already exists
        cr.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.columns 
                WHERE table_name = %s AND column_name = 'transport_company_id'
            )
        """, (table,))
        
        if cr.fetchone()[0]:
            _logger.info(f"Column transport_company_id already exists in {table}, skipping...")
            continue
        
        # Rename the column
        _logger.info(f"Renaming company_id to transport_company_id in {table}...")
        cr.execute(f"""
            ALTER TABLE {table} 
            RENAME COLUMN company_id TO transport_company_id
        """)
        
        _logger.info(f"Successfully renamed column in {table}")
    
    _logger.info("Migration completed successfully!")
