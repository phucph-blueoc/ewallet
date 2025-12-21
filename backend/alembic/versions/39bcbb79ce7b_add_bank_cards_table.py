"""add_bank_cards_table

Revision ID: 39bcbb79ce7b
Revises: d3fdd1ed4f09
Create Date: 2025-12-13 22:49:07.216078

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '39bcbb79ce7b'
down_revision: Union[str, Sequence[str], None] = 'd3fdd1ed4f09'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
