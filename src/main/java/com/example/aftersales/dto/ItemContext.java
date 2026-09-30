package com.example.aftersales.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 申请售后时需要的订单商品上下文：商品、所属订单、剩余可售后数量。
 */
public class ItemContext {

    private long itemId;
    private String productName;
    private String color;
    private String size;
    private int quantity;
    private BigDecimal unitPrice;
    private int afterSaleableQuantity;

    private long orderId;
    private String orderNo;
    private String orderStatus;
    private long orderUserId;
    private LocalDateTime completedAt;
    private int afterSaleDays;

    public long getItemId() { return itemId; }
    public void setItemId(long itemId) { this.itemId = itemId; }
    public String getProductName() { return productName; }
    public void setProductName(String productName) { this.productName = productName; }
    public String getColor() { return color; }
    public void setColor(String color) { this.color = color; }
    public String getSize() { return size; }
    public void setSize(String size) { this.size = size; }
    public int getQuantity() { return quantity; }
    public void setQuantity(int quantity) { this.quantity = quantity; }
    public BigDecimal getUnitPrice() { return unitPrice; }
    public void setUnitPrice(BigDecimal unitPrice) { this.unitPrice = unitPrice; }
    public int getAfterSaleableQuantity() { return afterSaleableQuantity; }
    public void setAfterSaleableQuantity(int afterSaleableQuantity) { this.afterSaleableQuantity = afterSaleableQuantity; }
    public long getOrderId() { return orderId; }
    public void setOrderId(long orderId) { this.orderId = orderId; }
    public String getOrderNo() { return orderNo; }
    public void setOrderNo(String orderNo) { this.orderNo = orderNo; }
    public String getOrderStatus() { return orderStatus; }
    public void setOrderStatus(String orderStatus) { this.orderStatus = orderStatus; }
    public long getOrderUserId() { return orderUserId; }
    public void setOrderUserId(long orderUserId) { this.orderUserId = orderUserId; }
    public LocalDateTime getCompletedAt() { return completedAt; }
    public void setCompletedAt(LocalDateTime completedAt) { this.completedAt = completedAt; }
    public int getAfterSaleDays() { return afterSaleDays; }
    public void setAfterSaleDays(int afterSaleDays) { this.afterSaleDays = afterSaleDays; }
}
