"""add_bill_tables

Revision ID: c6299b505107
Revises: 4f47fe8d6149
Create Date: 2025-12-14 06:36:09.358687

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c6299b505107'
down_revision: Union[str, Sequence[str], None] = '4f47fe8d6149'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create bill tables."""
    # Create bill_providers table
    op.create_table(
        'bill_providers',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('code', sa.String(), nullable=False),
        sa.Column('logo_url', sa.Text(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=True, server_default='true'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('code')
    )
    op.create_index(op.f('ix_bill_providers_id'), 'bill_providers', ['id'], unique=False)
    
    # Create saved_bills table
    op.create_table(
        'saved_bills',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('provider_id', sa.String(), nullable=False),
        sa.Column('customer_code', sa.String(), nullable=False),
        sa.Column('customer_name', sa.String(), nullable=True),
        sa.Column('alias', sa.String(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.ForeignKeyConstraint(['provider_id'], ['bill_providers.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_saved_bills_id'), 'saved_bills', ['id'], unique=False)
    op.create_index(op.f('ix_saved_bills_user_id'), 'saved_bills', ['user_id'], unique=False)
    
    # Create bill_transactions table
    op.create_table(
        'bill_transactions',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('provider_id', sa.String(), nullable=False),
        sa.Column('customer_code', sa.String(), nullable=False),
        sa.Column('amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('bill_period', sa.String(), nullable=True),
        sa.Column('transaction_id', sa.String(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.ForeignKeyConstraint(['provider_id'], ['bill_providers.id'], ),
        sa.ForeignKeyConstraint(['transaction_id'], ['transactions.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_bill_transactions_id'), 'bill_transactions', ['id'], unique=False)
    op.create_index(op.f('ix_bill_transactions_user_id'), 'bill_transactions', ['user_id'], unique=False)
    
    # Insert default bill providers (using Python uuid)
    import uuid
    providers = [
        (str(uuid.uuid4()), 'EVN (Điện lực)', 'EVN', True),
        (str(uuid.uuid4()), 'SAVACO (Nước)', 'SAVACO', True),
        (str(uuid.uuid4()), 'FPT Telecom', 'FPT', True),
        (str(uuid.uuid4()), 'Viettel Telecom', 'VIETTEL', True),
        (str(uuid.uuid4()), 'VinaPhone', 'VINAPHONE', True),
        (str(uuid.uuid4()), 'Mobifone', 'MOBIFONE', True),
    ]
    for provider_id, name, code, is_active in providers:
        op.execute(
            f"""
                INSERT INTO bill_providers (id, name, code, is_active) 
                VALUES ('{provider_id}', '{name}', '{code}', {str(is_active).upper()})
            """
        )


def downgrade() -> None:
    """Drop bill tables."""
    op.drop_index(op.f('ix_bill_transactions_user_id'), table_name='bill_transactions')
    op.drop_index(op.f('ix_bill_transactions_id'), table_name='bill_transactions')
    op.drop_table('bill_transactions')
    
    op.drop_index(op.f('ix_saved_bills_user_id'), table_name='saved_bills')
    op.drop_index(op.f('ix_saved_bills_id'), table_name='saved_bills')
    op.drop_table('saved_bills')
    
    op.drop_index(op.f('ix_bill_providers_id'), table_name='bill_providers')
    op.drop_table('bill_providers')
