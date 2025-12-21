"""add_notifications_and_alerts_tables

Revision ID: 523b04b658d8
Revises: dc48dbd76b18
Create Date: 2025-12-14 22:35:51.377982

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '523b04b658d8'
down_revision: Union[str, Sequence[str], None] = 'dc48dbd76b18'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create notifications, notification_settings, alert_settings, and alerts tables."""
    # Create notifications table
    op.create_table(
        'notifications',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('title', sa.String(), nullable=False),
        sa.Column('message', sa.Text(), nullable=False),
        sa.Column('type', sa.String(), nullable=False),
        sa.Column('is_read', sa.Boolean(), nullable=True, server_default='false'),
        sa.Column('data', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_notifications_id'), 'notifications', ['id'], unique=False)
    op.create_index(op.f('ix_notifications_user_id'), 'notifications', ['user_id'], unique=False)
    
    # Create notification_settings table
    op.create_table(
        'notification_settings',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('enable_transaction_notifications', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('enable_promotion_notifications', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('enable_security_notifications', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('enable_alert_notifications', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('device_token', sa.String(), nullable=True),
        sa.Column('device_type', sa.String(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id')
    )
    op.create_index(op.f('ix_notification_settings_id'), 'notification_settings', ['id'], unique=False)
    op.create_index(op.f('ix_notification_settings_user_id'), 'notification_settings', ['user_id'], unique=False)
    
    # Create alert_settings table
    op.create_table(
        'alert_settings',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('large_transaction_threshold', sa.Float(), nullable=True),
        sa.Column('low_balance_threshold', sa.Float(), nullable=True),
        sa.Column('budget_warning_percentage', sa.Float(), nullable=True, server_default='80.0'),
        sa.Column('enable_large_transaction_alert', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('enable_low_balance_alert', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('enable_budget_alert', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('enable_new_device_alert', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id')
    )
    op.create_index(op.f('ix_alert_settings_id'), 'alert_settings', ['id'], unique=False)
    op.create_index(op.f('ix_alert_settings_user_id'), 'alert_settings', ['user_id'], unique=False)
    
    # Create alerts table
    op.create_table(
        'alerts',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('type', sa.String(), nullable=False),
        sa.Column('title', sa.String(), nullable=False),
        sa.Column('message', sa.Text(), nullable=False),
        sa.Column('severity', sa.String(), nullable=True, server_default='INFO'),
        sa.Column('is_read', sa.Boolean(), nullable=True, server_default='false'),
        sa.Column('data', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_alerts_id'), 'alerts', ['id'], unique=False)
    op.create_index(op.f('ix_alerts_user_id'), 'alerts', ['user_id'], unique=False)


def downgrade() -> None:
    """Drop notifications, notification_settings, alert_settings, and alerts tables."""
    op.drop_index(op.f('ix_alerts_user_id'), table_name='alerts')
    op.drop_index(op.f('ix_alerts_id'), table_name='alerts')
    op.drop_table('alerts')
    
    op.drop_index(op.f('ix_alert_settings_user_id'), table_name='alert_settings')
    op.drop_index(op.f('ix_alert_settings_id'), table_name='alert_settings')
    op.drop_table('alert_settings')
    
    op.drop_index(op.f('ix_notification_settings_user_id'), table_name='notification_settings')
    op.drop_index(op.f('ix_notification_settings_id'), table_name='notification_settings')
    op.drop_table('notification_settings')
    
    op.drop_index(op.f('ix_notifications_user_id'), table_name='notifications')
    op.drop_index(op.f('ix_notifications_id'), table_name='notifications')
    op.drop_table('notifications')
