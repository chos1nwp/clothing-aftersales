package com.example.aftersales.domain;

/**
 * 时间线动作。visibleToConsumer 区分对外说明与内部记录。
 */
public enum ActionCode {

    APPLY("提交申请", true),
    SUPPLEMENT_REQUEST("要求补充材料", true),
    APPROVE_RETURN("同意退回", true),
    REJECT("拒绝申请", true),
    RESUBMIT("补充后重新提交", true),
    MARK_SHIPPED("确认已寄回", true),
    CANCEL("撤销申请", true),
    RECEIVE("仓库收到包裹", false),
    INSPECT_PASS("验货合格", false),
    INSPECT_ABNORMAL("验货异常", false),
    FINAL_EXCHANGE("确认换货并发出补发", true),
    FINAL_REFUND("确认退货并记录模拟退款", true),
    FINAL_REJECT("验货后拒绝", true);

    private final String label;
    private final boolean visibleToConsumer;

    ActionCode(String label, boolean visibleToConsumer) {
        this.label = label;
        this.visibleToConsumer = visibleToConsumer;
    }

    public String getLabel() {
        return label;
    }

    public boolean isVisibleToConsumer() {
        return visibleToConsumer;
    }
}
