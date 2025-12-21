"""add_user_devices_and_security_history_tables

Revision ID: 2f0541c82cc5
Revises: 523b04b658d8
Create Date: 2025-12-15 02:27:47.452090

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '2f0541c82cc5'
down_revision: Union[str, Sequence[str], None] = '523b04b658d8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create user_devices and security_history tables."""
    # Create user_devices table
    op.create_table(
        'user_devices',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('device_token', sa.String(), nullable=True),
        sa.Column('device_name', sa.String(), nullable=False),
        sa.Column('device_type', sa.String(), nullable=False),
        sa.Column('ip_address', sa.String(), nullable=True),
        sa.Column('user_agent', sa.String(), nullable=True),
        sa.Column('last_login', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=True, server_default='1'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_user_devices_id'), 'user_devices', ['id'], unique=False)
    op.create_index(op.f('ix_user_devices_user_id'), 'user_devices', ['user_id'], unique=False)

    # Create security_history table
    op.create_table(
        'security_history',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('action_type', sa.String(), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('ip_address', sa.String(), nullable=True),
        sa.Column('user_agent', sa.String(), nullable=True),
        sa.Column('device_id', sa.String(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.ForeignKeyConstraint(['device_id'], ['user_devices.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_security_history_id'), 'security_history', ['id'], unique=False)
    op.create_index(op.f('ix_security_history_user_id'), 'security_history', ['user_id'], unique=False)
    op.create_index(op.f('ix_security_history_created_at'), 'security_history', ['created_at'], unique=False)


def downgrade() -> None:
    """Drop user_devices and security_history tables."""
    op.drop_index(op.f('ix_security_history_created_at'), table_name='security_history')
    op.drop_index(op.f('ix_security_history_user_id'), table_name='security_history')
    op.drop_index(op.f('ix_security_history_id'), table_name='security_history')
    op.drop_table('security_history')
    op.drop_index(op.f('ix_user_devices_user_id'), table_name='user_devices')
    op.drop_index(op.f('ix_user_devices_id'), table_name='user_devices')
    op.drop_table('user_devices')
