package com.example.aftersales.domain;

/**
 * 会话中保存的登录身份，不含密码散列。
 */
public record LoginUser(long id, String username, String displayName, UserRole role) {

    public boolean isConsumer() {
        return role == UserRole.CONSUMER;
    }
}
