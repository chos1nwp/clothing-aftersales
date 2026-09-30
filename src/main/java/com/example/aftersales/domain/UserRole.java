package com.example.aftersales.domain;

public enum UserRole {

    CONSUMER("消费者"),
    CS("售后客服"),
    WAREHOUSE("仓库人员");

    private final String label;

    UserRole(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }

    public static UserRole of(String value) {
        for (UserRole role : values()) {
            if (role.name().equals(value)) {
                return role;
            }
        }
        throw new IllegalArgumentException("未知岗位：" + value);
    }
}
