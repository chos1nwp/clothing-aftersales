package com.example.aftersales.entity;

import com.example.aftersales.domain.AftersalesStatus;
import com.example.aftersales.domain.ActionCode;
import com.example.aftersales.domain.UserRole;

import java.time.LocalDateTime;

public class ActionLogDO {

    private long id;
    private long aftersalesId;
    private ActionCode action;
    private AftersalesStatus fromStatus;
    private AftersalesStatus toStatus;
    private long operatorUserId;
    private UserRole operatorRole;
    private String operatorName;
    private String note;
    private boolean visibleToConsumer;
    private LocalDateTime createdAt;

    public long getId() { return id; }
    public void setId(long id) { this.id = id; }
    public long getAftersalesId() { return aftersalesId; }
    public void setAftersalesId(long aftersalesId) { this.aftersalesId = aftersalesId; }
    public ActionCode getAction() { return action; }
    public void setAction(ActionCode action) { this.action = action; }
    public AftersalesStatus getFromStatus() { return fromStatus; }
    public void setFromStatus(AftersalesStatus fromStatus) { this.fromStatus = fromStatus; }
    public AftersalesStatus getToStatus() { return toStatus; }
    public void setToStatus(AftersalesStatus toStatus) { this.toStatus = toStatus; }
    public long getOperatorUserId() { return operatorUserId; }
    public void setOperatorUserId(long operatorUserId) { this.operatorUserId = operatorUserId; }
    public UserRole getOperatorRole() { return operatorRole; }
    public void setOperatorRole(UserRole operatorRole) { this.operatorRole = operatorRole; }
    public String getOperatorName() { return operatorName; }
    public void setOperatorName(String operatorName) { this.operatorName = operatorName; }
    public String getNote() { return note; }
    public void setNote(String note) { this.note = note; }
    public boolean isVisibleToConsumer() { return visibleToConsumer; }
    public void setVisibleToConsumer(boolean visibleToConsumer) { this.visibleToConsumer = visibleToConsumer; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
