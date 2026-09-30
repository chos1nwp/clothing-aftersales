package com.example.aftersales.domain;

public enum AftersalesType {

    RETURN("退货"),
    EXCHANGE("换货");

    private final String label;

    AftersalesType(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }
}
