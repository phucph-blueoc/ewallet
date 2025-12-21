"""Add transaction PIN hash to users

Revision ID: fe12b1f5c3c4
Revises: d578e16cc3d9
Create Date: 2025-12-08 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'fe12b1f5c3c4'
down_revision: Union[str, Sequence[str], None] = 'd578e16cc3d9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add transaction_pin_hash column to users table."""
    with op.batch_alter_table('users') as batch_op:
        batch_op.add_column(sa.Column('transaction_pin_hash', sa.String(), nullable=True))


def downgrade() -> None:
    """Remove transaction_pin_hash column from users table."""
    with op.batch_alter_table('users') as batch_op:
        batch_op.drop_column('transaction_pin_hash')


