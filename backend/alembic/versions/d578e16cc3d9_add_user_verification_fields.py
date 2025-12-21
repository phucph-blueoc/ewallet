"""add_user_verification_fields

Revision ID: d578e16cc3d9
Revises: aa84d30fc420
Create Date: 2025-12-03 08:27:48.799219

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd578e16cc3d9'
down_revision: Union[str, Sequence[str], None] = 'aa84d30fc420'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add is_verified and otp_created_at columns to users table."""
    # SQLite doesn't support ALTER COLUMN, so we add columns with server_default
    # Add is_verified column with default True for existing users
    with op.batch_alter_table('users') as batch_op:
        batch_op.add_column(sa.Column('is_verified', sa.Boolean(), server_default='1', nullable=False))
        batch_op.add_column(sa.Column('otp_created_at', sa.DateTime(), nullable=True))
    
    # Add indexes for better query performance (check if not exists)
    try:
        op.create_index('ix_transactions_sender_id', 'transactions', ['sender_id'], unique=False)
    except:
        pass  # Index might already exist
    
    try:
        op.create_index('ix_transactions_receiver_id', 'transactions', ['receiver_id'], unique=False)
    except:
        pass  # Index might already exist


def downgrade() -> None:
    """Remove is_verified and otp_created_at columns from users table."""
    # Drop indexes
    try:
        op.drop_index('ix_transactions_receiver_id', table_name='transactions')
    except:
        pass
    
    try:
        op.drop_index('ix_transactions_sender_id', table_name='transactions')
    except:
        pass
    
    # Drop columns
    with op.batch_alter_table('users') as batch_op:
        batch_op.drop_column('otp_created_at')
        batch_op.drop_column('is_verified')
