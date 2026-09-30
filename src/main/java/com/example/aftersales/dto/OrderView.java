package com.example.aftersales.dto;

import java.time.LocalDateTime;
import java.util.List;

public class OrderView {

    private long id;
    private String orderNo;
    private String status;
    private LocalDateTime placedAt;
    private LocalDateTime completedAt;
    private int afterSaleDays;
    private LocalDateTime afterSaleDeadline;
    private boolean afterSaleOpen;
    private List<OrderItemView> items;

    public long getId() { return id; }
    public void setId(long id) { this.id = id; }
    public String getOrderNo() { return orderNo; }
    public void setOrderNo(String orderNo) { this.orderNo = orderNo; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public LocalDateTime getPlacedAt() { return placedAt; }
    public void setPlacedAt(LocalDateTime placedAt) { this.placedAt = placedAt; }
    public LocalDateTime getCompletedAt() { return completedAt; }
    public void setCompletedAt(LocalDateTime completedAt) { this.completedAt = completedAt; }
    public int getAfterSaleDays() { return afterSaleDays; }
    public void setAfterSaleDays(int afterSaleDays) { this.afterSaleDays = afterSaleDays; }
    public LocalDateTime getAfterSaleDeadline() { return afterSaleDeadline; }
    public void setAfterSaleDeadline(LocalDateTime afterSaleDeadline) { this.afterSaleDeadline = afterSaleDeadline; }
    public boolean isAfterSaleOpen() { return afterSaleOpen; }
    public void setAfterSaleOpen(boolean afterSaleOpen) { this.afterSaleOpen = afterSaleOpen; }
    public List<OrderItemView> getItems() { return items; }
    public void setItems(List<OrderItemView> items) { this.items = items; }
}
