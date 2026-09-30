package com.example.aftersales.domain;

public enum ReasonCode {

    SIZE("尺码不合适"),
    DAMAGED("商品破损"),
    WRONG_ITEM("商家错发"),
    QUALITY("质量问题"),
    OTHER("其他原因");

    private final String label;

    ReasonCode(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }
}
