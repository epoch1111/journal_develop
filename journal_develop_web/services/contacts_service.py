"""联系人 - 业务逻辑层"""

from database import list_user_contacts


def get_contacts(user_id: int) -> list[dict]:
    """获取用户的所有联系人"""
    return list_user_contacts(user_id)
