package com.example.aftersales.domain;

import java.util.Collections;
import java.util.EnumSet;
import java.util.Map;
import java.util.Set;

/**
 * 售后单状态机。白名单来自 docs/03-design.md 第 2 节，未登记的跳转一律拒绝。
 */
public enum AftersalesStatus {

    PENDING_REVIEW("待审核"),
    NEED_SUPPLEMENT("待补充"),
    WAIT_RETURN("待退回"),
    WAIT_RECEIPT("待收货"),
    WAIT_FINAL_REVIEW("待确认"),
    COMPLETED("已完成"),
    REJECTED("已拒绝"),
    CANCELLED("已取消");

    private final String label;

    AftersalesStatus(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }

    public boolean isClosed() {
        return this == COMPLETED || this == REJECTED || this == CANCELLED;
    }

    private static final Map<AftersalesStatus, Set<AftersalesStatus>> TRANSITIONS = Map.of(
            PENDING_REVIEW, EnumSet.of(NEED_SUPPLEMENT, WAIT_RETURN, REJECTED, CANCELLED),
            NEED_SUPPLEMENT, EnumSet.of(PENDING_REVIEW, CANCELLED),
            WAIT_RETURN, EnumSet.of(WAIT_RECEIPT, CANCELLED),
            WAIT_RECEIPT, EnumSet.of(WAIT_FINAL_REVIEW),
            WAIT_FINAL_REVIEW, EnumSet.of(COMPLETED, REJECTED),
            COMPLETED, Collections.emptySet(),
            REJECTED, Collections.emptySet(),
            CANCELLED, Collections.emptySet()
    );

    public boolean canMoveTo(AftersalesStatus target) {
        return TRANSITIONS.get(this).contains(target);
    }

    public static AftersalesStatus of(String value) {
        return AftersalesStatus.valueOf(value);
    }
}
