package com.example.aftersales.dto;

import java.time.LocalDateTime;

public class OrderItemView {

    private long id;
    private String productName;
    private String color;
    private String size;
    private int quantity;
    private java.math.BigDecimal unitPrice;
    private int afterSaleableQuantity;

    public long getId() { return id; }
    public void setId(long id) { this.id = id; }
    public String getProductName() { return productName; }
    public void setProductName(String productName) { this.productName = productName; }
    public String getColor() { return color; }
    public void setColor(String color) { this.color = color; }
    public String getSize() { return size; }
    public void setSize(String size) { this.size = size; }
    public int getQuantity() { return quantity; }
    public void setQuantity(int quantity) { this.quantity = quantity; }
    public java.math.BigDecimal getUnitPrice() { return unitPrice; }
    public void setUnitPrice(java.math.BigDecimal unitPrice) { this.unitPrice = unitPrice; }
    public int getAfterSaleableQuantity() { return afterSaleableQuantity; }
    public void setAfterSaleableQuantity(int afterSaleableQuantity) { this.afterSaleableQuantity = afterSaleableQuantity; }
}
