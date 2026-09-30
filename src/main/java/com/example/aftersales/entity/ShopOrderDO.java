package com.example.aftersales.entity;

import java.time.LocalDateTime;

public class ShopOrderDO {

    private long id;
    private String orderNo;
    private long userId;
    private String status;
    private LocalDateTime placedAt;
    private LocalDateTime completedAt;
    private int afterSaleDays;

    public long getId() { return id; }
    public void setId(long id) { this.id = id; }
    public String getOrderNo() { return orderNo; }
    public void setOrderNo(String orderNo) { this.orderNo = orderNo; }
    public long getUserId() { return userId; }
    public void setUserId(long userId) { this.userId = userId; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public LocalDateTime getPlacedAt() { return placedAt; }
    public void setPlacedAt(LocalDateTime placedAt) { this.placedAt = placedAt; }
    public LocalDateTime getCompletedAt() { return completedAt; }
    public void setCompletedAt(LocalDateTime completedAt) { this.completedAt = completedAt; }
    public int getAfterSaleDays() { return afterSaleDays; }
    public void setAfterSaleDays(int afterSaleDays) { this.afterSaleDays = afterSaleDays; }
}
