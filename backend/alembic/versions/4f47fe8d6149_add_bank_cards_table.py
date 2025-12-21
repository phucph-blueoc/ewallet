"""add_bank_cards_table

Revision ID: 4f47fe8d6149
Revises: 39bcbb79ce7b
Create Date: 2025-12-13 22:50:30.989991

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '4f47fe8d6149'
down_revision: Union[str, Sequence[str], None] = '39bcbb79ce7b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create bank_cards table."""
    op.create_table(
        'bank_cards',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('card_number_encrypted', sa.String(), nullable=False),
        sa.Column('card_holder_name', sa.String(), nullable=False),
        sa.Column('expiry_date_encrypted', sa.String(), nullable=False),
        sa.Column('cvv_encrypted', sa.String(), nullable=False),
        sa.Column('bank_name', sa.String(), nullable=False),
        sa.Column('card_type', sa.String(), nullable=False),
        sa.Column('is_verified', sa.Boolean(), nullable=True, server_default='false'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_bank_cards_id'), 'bank_cards', ['id'], unique=False)
    op.create_index(op.f('ix_bank_cards_user_id'), 'bank_cards', ['user_id'], unique=False)


def downgrade() -> None:
    """Drop bank_cards table."""
    op.drop_index(op.f('ix_bank_cards_user_id'), table_name='bank_cards')
    op.drop_index(op.f('ix_bank_cards_id'), table_name='bank_cards')
    op.drop_table('bank_cards')
