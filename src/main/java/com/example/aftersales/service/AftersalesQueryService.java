package com.example.aftersales.service;

import com.example.aftersales.common.BizException;
import com.example.aftersales.domain.AftersalesStatus;
import com.example.aftersales.domain.AftersalesType;
import com.example.aftersales.domain.LoginUser;
import com.example.aftersales.domain.ReasonCode;
import com.example.aftersales.domain.UserRole;
import com.example.aftersales.dto.AftersalesView;
import com.example.aftersales.dto.OrderView;
import com.example.aftersales.dto.StatusCount;
import com.example.aftersales.entity.WarehouseRecordDO;
import com.example.aftersales.mapper.ActionLogMapper;
import com.example.aftersales.mapper.AftersalesMapper;
import com.example.aftersales.mapper.OrderMapper;
import com.example.aftersales.mapper.WarehouseMapper;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class AftersalesQueryService {

    private final OrderMapper orderMapper;
    private final AftersalesMapper aftersalesMapper;
    private final WarehouseMapper warehouseMapper;
    private final ActionLogMapper actionLogMapper;
    private final EvidenceService evidenceService;

    public AftersalesQueryService(OrderMapper orderMapper,
                                  AftersalesMapper aftersalesMapper,
                                  WarehouseMapper warehouseMapper,
                                  ActionLogMapper actionLogMapper,
                                  EvidenceService evidenceService) {
        this.orderMapper = orderMapper;
        this.aftersalesMapper = aftersalesMapper;
        this.warehouseMapper = warehouseMapper;
        this.actionLogMapper = actionLogMapper;
        this.evidenceService = evidenceService;
    }

    public List<OrderView> consumerOrders(LoginUser user) {
        List<OrderView> orders = orderMapper.findOrdersWithItems(user.id());
        LocalDateTime now = LocalDateTime.now();
        for (OrderView order : orders) {
            LocalDateTime deadline = order.getCompletedAt() == null
                    ? null : order.getCompletedAt().plusDays(order.getAfterSaleDays());
            order.setAfterSaleDeadline(deadline);
            order.setAfterSaleOpen("COMPLETED".equals(order.getStatus())
                    && deadline != null && !now.isAfter(deadline));
        }
        return orders;
    }

    public List<AftersalesView> myAftersales(LoginUser user, String status) {
        List<AftersalesView> list = aftersalesMapper.listByConsumer(user.id(), status);
        list.forEach(this::fillLabels);
        return list;
    }

    public List<AftersalesView> staffList(LoginUser user, String status, String type, String keyword) {
        String effectiveStatus = status;
        if (user.role() == UserRole.WAREHOUSE && (status == null || status.isBlank())) {
            effectiveStatus = AftersalesStatus.WAIT_RECEIPT.name();
        }
        List<AftersalesView> list = aftersalesMapper.listForStaff(effectiveStatus, type, keyword);
        list.forEach(this::fillLabels);
        return list;
    }

    public List<StatusCount> statusCounts() {
        return aftersalesMapper.countByStatus();
    }

    public AftersalesView detail(LoginUser user, long id) {
        AftersalesView view = aftersalesMapper.findDetail(id);
        if (view == null) {
            throw BizException.forbidden("售后单不存在或你无权查看");
        }
        boolean consumerView = user.role() == UserRole.CONSUMER;
        if (consumerView && view.getConsumerUserId() != user.id()) {
            // 不区分"不存在"和"无权"，避免暴露他人单据是否存在
            throw BizException.forbidden("售后单不存在或你无权查看");
        }
        fillLabels(view);

        WarehouseRecordDO warehouse = warehouseMapper.findByAftersalesId(id);
        if (consumerView && warehouse != null) {
            WarehouseRecordDO publicRecord = new WarehouseRecordDO();
            publicRecord.setAftersalesId(id);
            publicRecord.setReceivedAt(warehouse.getReceivedAt());
            publicRecord.setInspectedAt(warehouse.getInspectedAt());
            publicRecord.setInspectionResult(warehouse.getInspectionResult());
            warehouse = publicRecord;
        }
        view.setWarehouseRecord(warehouse);
        view.setEvidenceList(evidenceService.list(id));
        view.setTimeline(actionLogMapper.findByAftersalesId(id, consumerView));
        return view;
    }

    private void fillLabels(AftersalesView view) {
        view.setStatusLabel(AftersalesStatus.valueOf(view.getStatus()).getLabel());
        view.setTypeLabel(AftersalesType.valueOf(view.getType()).getLabel());
        view.setReasonLabel(ReasonCode.valueOf(view.getReasonCode()).getLabel());
    }
}
