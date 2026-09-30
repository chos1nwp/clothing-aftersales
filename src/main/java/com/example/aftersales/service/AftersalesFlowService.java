package com.example.aftersales.service;

import com.example.aftersales.common.BizException;
import com.example.aftersales.domain.ActionCode;
import com.example.aftersales.domain.AftersalesStatus;
import com.example.aftersales.domain.AftersalesType;
import com.example.aftersales.domain.LoginUser;
import com.example.aftersales.domain.ReasonCode;
import com.example.aftersales.dto.ApplyRequest;
import com.example.aftersales.dto.FinalizeRequest;
import com.example.aftersales.dto.InspectRequest;
import com.example.aftersales.dto.ItemContext;
import com.example.aftersales.dto.MarkShippedRequest;
import com.example.aftersales.dto.ReceiveRequest;
import com.example.aftersales.dto.ResubmitRequest;
import com.example.aftersales.dto.ReviewRequest;
import com.example.aftersales.entity.AftersalesOrderDO;
import com.example.aftersales.entity.ActionLogDO;
import com.example.aftersales.entity.WarehouseRecordDO;
import com.example.aftersales.mapper.ActionLogMapper;
import com.example.aftersales.mapper.AftersalesMapper;
import com.example.aftersales.mapper.OrderMapper;
import com.example.aftersales.mapper.WarehouseMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Map;

/**
 * 售后单写操作。每个方法遵守同一套约束：
 * 校验当前状态 -> 校验岗位与归属 -> 状态机跳转 -> 乐观更新 -> 写时间线。
 */
@Service
public class AftersalesFlowService {

    private final AftersalesMapper aftersalesMapper;
    private final OrderMapper orderMapper;
    private final WarehouseMapper warehouseMapper;
    private final ActionLogMapper actionLogMapper;
    private final EvidenceService evidenceService;

    public AftersalesFlowService(AftersalesMapper aftersalesMapper,
                                 OrderMapper orderMapper,
                                 WarehouseMapper warehouseMapper,
                                 ActionLogMapper actionLogMapper,
                                 EvidenceService evidenceService) {
        this.aftersalesMapper = aftersalesMapper;
        this.orderMapper = orderMapper;
        this.warehouseMapper = warehouseMapper;
        this.actionLogMapper = actionLogMapper;
        this.evidenceService = evidenceService;
    }

    // ---------- 消费者 ----------

    @Transactional
    public long apply(LoginUser user, ApplyRequest request) {
        ItemContext item = orderMapper.findItemContext(request.orderItemId());
        if (item == null) {
            throw BizException.badRequest("订单商品不存在");
        }
        if (item.getOrderUserId() != user.id()) {
            throw BizException.forbidden("只能对本人订单申请售后");
        }
        if (!"COMPLETED".equals(item.getOrderStatus())) {
            throw BizException.badRequest("该订单尚未完成签收，不能申请售后");
        }
        LocalDateTime deadline = item.getCompletedAt().plusDays(item.getAfterSaleDays());
        if (LocalDateTime.now().isAfter(deadline)) {
            throw BizException.badRequest("已超过售后期限（签收后 " + item.getAfterSaleDays() + " 天内可申请）");
        }

        AftersalesType type = parseType(request.type());
        ReasonCode reason = parseReason(request.reasonCode());

        if (aftersalesMapper.countOpenByItem(item.getItemId()) > 0) {
            throw BizException.conflict("该商品已有正在处理中的售后申请，请先处理完再提交");
        }
        if (request.quantity() > item.getAfterSaleableQuantity()) {
            throw BizException.badRequest("申请数量超出可售后数量，该商品当前最多可申请 "
                    + item.getAfterSaleableQuantity() + " 件");
        }

        AftersalesOrderDO record = new AftersalesOrderDO();
        record.setAftersalesNo("TMP");
        record.setOrderItemId(item.getItemId());
        record.setConsumerUserId(user.id());
        record.setType(type);
        record.setReasonCode(reason);
        record.setQuantity(request.quantity());
        record.setDescription(request.description().trim());
        record.setStatus(AftersalesStatus.PENDING_REVIEW);
        aftersalesMapper.insert(record);
        aftersalesMapper.updateAftersalesNo(record.getId(), buildNo(record.getId()));

        writeLog(record.getId(), null, AftersalesStatus.PENDING_REVIEW, ActionCode.APPLY, user,
                "提交" + type.getLabel() + "申请：" + reason.getLabel() + "，数量 " + request.quantity());
        return record.getId();
    }

    @Transactional
    public void uploadEvidence(LoginUser user, long aftersalesId, org.springframework.web.multipart.MultipartFile file) {
        AftersalesOrderDO record = requireExisting(aftersalesId);
        requireOwnerOrStaff(user, record);
        if (record.getStatus().isClosed()) {
            throw BizException.conflict("该售后单已关闭，不能再补充凭证");
        }
        evidenceService.save(aftersalesId, file, user.id());
    }

    @Transactional
    public void resubmit(LoginUser user, long aftersalesId, ResubmitRequest request) {
        AftersalesOrderDO record = requireExisting(aftersalesId);
        requireOwner(user, record);
        AftersalesStatus from = record.getStatus();
        if (from != AftersalesStatus.NEED_SUPPLEMENT) {
            throw conflict(from, AftersalesStatus.NEED_SUPPLEMENT);
        }
        moveTo(record, from, AftersalesStatus.PENDING_REVIEW, update -> update.setDescription(request.description().trim()));
        writeLog(aftersalesId, from, AftersalesStatus.PENDING_REVIEW, ActionCode.RESUBMIT, user, "补充材料后重新提交审核");
    }

    @Transactional
    public void markShipped(LoginUser user, long aftersalesId, MarkShippedRequest request) {
        AftersalesOrderDO record = requireExisting(aftersalesId);
        requireOwner(user, record);
        AftersalesStatus from = record.getStatus();
        if (from != AftersalesStatus.WAIT_RETURN) {
            throw conflict(from, AftersalesStatus.WAIT_RETURN);
        }
        moveTo(record, from, AftersalesStatus.WAIT_RECEIPT,
                update -> update.setConsumerParcelNo(request.parcelNo().trim()));
        writeLog(aftersalesId, from, AftersalesStatus.WAIT_RECEIPT, ActionCode.MARK_SHIPPED, user,
                "已寄回包裹，单号 " + request.parcelNo().trim());
    }

    @Transactional
    public void cancel(LoginUser user, long aftersalesId) {
        AftersalesOrderDO record = requireExisting(aftersalesId);
        requireOwner(user, record);
        AftersalesStatus from = record.getStatus();
        if (from != AftersalesStatus.PENDING_REVIEW
                && from != AftersalesStatus.NEED_SUPPLEMENT
                && from != AftersalesStatus.WAIT_RETURN) {
            throw BizException.conflict("仓库已开始处理或售后单已关闭，无法撤销");
        }
        moveTo(record, from, AftersalesStatus.CANCELLED, update -> update.setClosedAt(LocalDateTime.now()));
        writeLog(aftersalesId, from, AftersalesStatus.CANCELLED, ActionCode.CANCEL, user, "消费者主动撤销申请");
    }

    // ---------- 客服 ----------

    /** 客服审核动作 -> (目标状态, 时间线动作)。请求里的动作名与日志动作名不完全相同。 */
    private static final Map<String, ActionPlan> REVIEW_ACTIONS = Map.of(
            "APPROVE_RETURN", new ActionPlan(AftersalesStatus.WAIT_RETURN, ActionCode.APPROVE_RETURN),
            "NEED_SUPPLEMENT", new ActionPlan(AftersalesStatus.NEED_SUPPLEMENT, ActionCode.SUPPLEMENT_REQUEST),
            "REJECT", new ActionPlan(AftersalesStatus.REJECTED, ActionCode.REJECT));

    private record ActionPlan(AftersalesStatus target, ActionCode logCode) {
    }

    @Transactional
    public void review(LoginUser user, long aftersalesId, ReviewRequest request) {
        AftersalesOrderDO record = requireExisting(aftersalesId);
        AftersalesStatus from = record.getStatus();
        if (from != AftersalesStatus.PENDING_REVIEW) {
            throw BizException.conflict("该售后单不在待审核状态，可能已被其他客服处理");
        }

        ActionPlan plan = REVIEW_ACTIONS.get(request.action());
        if (plan == null) {
            throw BizException.badRequest("审核动作只能是同意退回、要求补充或拒绝");
        }
        AftersalesStatus to = plan.target();

        if (plan.logCode() == ActionCode.APPROVE_RETURN) {
            requireText(request.returnGuidance(), 5, "同意退回时必须填写退回指引");
            moveTo(record, from, to, update -> update.setReturnGuidance(request.returnGuidance().trim()));
            writeLog(aftersalesId, from, to, plan.logCode(), user,
                    textOr(request.note(), "审核通过，同意退回"));
        } else if (plan.logCode() == ActionCode.SUPPLEMENT_REQUEST) {
            requireText(request.note(), 5, "要求补充材料时必须说明缺少什么");
            moveTo(record, from, to, update -> {
            });
            writeLog(aftersalesId, from, to, plan.logCode(), user, request.note().trim());
        } else {
            requireText(request.note(), 5, "拒绝申请时必须填写理由");
            moveTo(record, from, to, update -> {
                update.setFinalNote(request.note().trim());
                update.setClosedAt(LocalDateTime.now());
            });
            writeLog(aftersalesId, from, to, plan.logCode(), user, request.note().trim());
        }
    }

    @Transactional
    public void finalize(LoginUser user, long aftersalesId, FinalizeRequest request) {
        AftersalesOrderDO record = requireExisting(aftersalesId);
        AftersalesStatus from = record.getStatus();
        if (from != AftersalesStatus.WAIT_FINAL_REVIEW) {
            throw BizException.conflict("仓库尚未完成验货，客服还不能下最终结论");
        }
        WarehouseRecordDO warehouse = warehouseMapper.findByAftersalesId(aftersalesId);
        if (warehouse == null || !warehouse.isInspected()) {
            throw BizException.conflict("缺少仓库验货记录，不能确认退款或换货");
        }

        ActionCode action = parseAction(request.action(), ActionCode.FINAL_EXCHANGE,
                ActionCode.FINAL_REFUND, ActionCode.FINAL_REJECT);

        if (action == ActionCode.FINAL_REJECT) {
            requireText(request.note(), 5, "拒绝时必须填写理由");
            moveTo(record, from, AftersalesStatus.REJECTED,
                    update -> {
                        update.setFinalNote(request.note().trim());
                        update.setClosedAt(LocalDateTime.now());
                    });
            writeLog(aftersalesId, from, AftersalesStatus.REJECTED, action, user, request.note().trim());
            return;
        }

        requireText(request.note(), 5, "请填写处理结论说明，便于后续追溯");
        if (action == ActionCode.FINAL_EXCHANGE) {
            if (record.getType() != AftersalesType.EXCHANGE) {
                throw BizException.badRequest("该售后单是退货，不能按换货处理");
            }
            requireText(request.trackingNo(), 4, "换货必须填写模拟补发单号");
            moveTo(record, from, AftersalesStatus.COMPLETED,
                    update -> {
                        update.setResendTrackingNo(request.trackingNo().trim());
                        update.setFinalNote(request.note().trim());
                        update.setClosedAt(LocalDateTime.now());
                    });
        } else {
            if (record.getType() != AftersalesType.RETURN) {
                throw BizException.badRequest("该售后单是换货，不能按退货处理");
            }
            BigDecimal refund = computeRefund(record);
            moveTo(record, from, AftersalesStatus.COMPLETED,
                    update -> {
                        update.setRefundAmount(refund);
                        update.setFinalNote(request.note().trim());
                        update.setClosedAt(LocalDateTime.now());
                    });
        }
        writeLog(aftersalesId, from, AftersalesStatus.COMPLETED, action, user, request.note().trim());
    }

    // ---------- 仓库 ----------

    @Transactional
    public void receive(LoginUser user, long aftersalesId, ReceiveRequest request) {
        AftersalesOrderDO record = requireExisting(aftersalesId);
        if (record.getStatus().isClosed()) {
            throw BizException.conflict("该售后单已关闭（" + record.getStatus().getLabel() + "），不能再登记收货");
        }
        if (record.getStatus() != AftersalesStatus.WAIT_RECEIPT) {
            throw BizException.conflict("客服尚未同意退回或消费者尚未确认寄回，仓库不能提前登记收货");
        }
        WarehouseRecordDO existing = warehouseMapper.findByAftersalesId(aftersalesId);
        if (existing != null && existing.isReceived()) {
            throw BizException.conflict("该售后单的退回包裹已登记收货，不能重复登记");
        }

        if (existing == null) {
            WarehouseRecordDO created = new WarehouseRecordDO();
            created.setAftersalesId(aftersalesId);
            created.setParcelNo(request.parcelNo().trim());
            created.setReceivedAt(LocalDateTime.now());
            created.setReceivedBy(user.id());
            warehouseMapper.insert(created);
            if (created.getId() == 0) {
                throw BizException.conflict("该售后单已被其他仓库人员登记，请刷新后重试");
            }
        } else {
            existing.setParcelNo(request.parcelNo().trim());
            existing.setReceivedBy(user.id());
            if (warehouseMapper.updateReceipt(existing) == 0) {
                throw BizException.conflict("该售后单已被其他仓库人员登记，请刷新后重试");
            }
        }
        writeLog(aftersalesId, record.getStatus(), record.getStatus(), ActionCode.RECEIVE, user,
                "收到退回包裹，单号 " + request.parcelNo().trim());
    }

    @Transactional
    public void inspect(LoginUser user, long aftersalesId, InspectRequest request) {
        AftersalesOrderDO record = requireExisting(aftersalesId);
        AftersalesStatus from = record.getStatus();
        WarehouseRecordDO warehouse = warehouseMapper.findByAftersalesId(aftersalesId);
        // 先判断是否已验货：验货后单据已进入待确认，此时提示「尚未登记收货」会误导仓库人员
        if (warehouse != null && warehouse.isInspected()) {
            throw BizException.conflict("该售后单已完成验货登记");
        }
        if (from != AftersalesStatus.WAIT_RECEIPT) {
            throw BizException.conflict("尚未登记收货，不能直接登记验货结果");
        }
        if (warehouse == null || !warehouse.isReceived()) {
            throw BizException.conflict("请先登记收到退回包裹，再填写验货结果");
        }

        boolean abnormal;
        if ("ABNORMAL".equals(request.result())) {
            abnormal = true;
        } else if ("PASS".equals(request.result())) {
            abnormal = false;
        } else {
            throw BizException.badRequest("验货结果只能选择合格或异常");
        }
        if (abnormal) {
            requireText(request.issueDescription(), 5, "验货异常必须写清具体现象");
        }

        warehouse.setInspectionResult(request.result());
        warehouse.setIssueDescription(abnormal ? request.issueDescription().trim() : null);
        warehouse.setInspectedBy(user.id());
        if (warehouseMapper.updateInspection(warehouse) == 0) {
            throw BizException.conflict("该售后单已被其他仓库人员验货，请刷新后重试");
        }

        moveTo(record, from, AftersalesStatus.WAIT_FINAL_REVIEW, update -> {
        });
        writeLog(aftersalesId, from, AftersalesStatus.WAIT_FINAL_REVIEW,
                abnormal ? ActionCode.INSPECT_ABNORMAL : ActionCode.INSPECT_PASS, user,
                abnormal ? "验货异常：" + request.issueDescription().trim() : "验货合格，退回商品可进入处理");
    }

    // ---------- 公共校验 ----------

    private AftersalesOrderDO requireExisting(long id) {
        AftersalesOrderDO record = aftersalesMapper.findById(id);
        if (record == null) {
            throw BizException.forbidden("售后单不存在或你无权查看");
        }
        return record;
    }

    private void requireOwner(LoginUser user, AftersalesOrderDO record) {
        if (record.getConsumerUserId() != user.id()) {
            throw BizException.forbidden("售后单不存在或你无权查看");
        }
    }

    private void requireOwnerOrStaff(LoginUser user, AftersalesOrderDO record) {
        if (user.isConsumer() && record.getConsumerUserId() != user.id()) {
            throw BizException.forbidden("售后单不存在或你无权查看");
        }
    }

    private void moveTo(AftersalesOrderDO record, AftersalesStatus from, AftersalesStatus to,
                        java.util.function.Consumer<AftersalesOrderDO> extra) {
        if (!from.canMoveTo(to)) {
            throw BizException.conflict("状态不允许从「" + from.getLabel() + "」直接变为「" + to.getLabel() + "」");
        }
        AftersalesOrderDO update = new AftersalesOrderDO();
        update.setId(record.getId());
        update.setStatus(to);
        extra.accept(update);
        if (aftersalesMapper.updateState(update, from) == 0) {
            throw BizException.conflict("该售后单刚被其他人处理，请刷新后重试");
        }
    }

    private void writeLog(long aftersalesId, AftersalesStatus from, AftersalesStatus to,
                          ActionCode action, LoginUser operator, String note) {
        ActionLogDO log = new ActionLogDO();
        log.setAftersalesId(aftersalesId);
        log.setAction(action);
        log.setFromStatus(from);
        log.setToStatus(to);
        log.setOperatorUserId(operator.id());
        log.setOperatorRole(operator.role());
        log.setNote(note);
        log.setVisibleToConsumer(action.isVisibleToConsumer());
        actionLogMapper.insert(log);
    }

    private BigDecimal computeRefund(AftersalesOrderDO record) {
        ItemContext item = orderMapper.findItemContext(record.getOrderItemId());
        if (item == null) {
            throw BizException.badRequest("订单商品数据缺失，无法计算退款金额");
        }
        return item.getUnitPrice().multiply(BigDecimal.valueOf(record.getQuantity()));
    }

    private BizException conflict(AftersalesStatus actual, AftersalesStatus expected) {
        return BizException.conflict("当前状态为「" + actual.getLabel() + "」，需要处于「"
                + expected.getLabel() + "」才能执行该操作");
    }

    private void requireText(String value, int minLength, String message) {
        if (value == null || value.trim().length() < minLength) {
            throw BizException.badRequest(message);
        }
    }

    private String textOr(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value.trim();
    }

    private <E extends Enum<E>> E parseAction(String value, E... allowed) {
        for (E candidate : allowed) {
            if (candidate.name().equals(value)) {
                return candidate;
            }
        }
        throw BizException.badRequest("不支持的操作类型");
    }

    private AftersalesType parseType(String value) {
        try {
            return AftersalesType.valueOf(value);
        } catch (IllegalArgumentException e) {
            throw BizException.badRequest("售后类型只能是退货或换货");
        }
    }

    private ReasonCode parseReason(String value) {
        try {
            return ReasonCode.valueOf(value);
        } catch (IllegalArgumentException e) {
            throw BizException.badRequest("请选择有效的申请原因");
        }
    }

    private String buildNo(long id) {
        return "AS" + LocalDateTime.now().format(java.time.format.DateTimeFormatter.ofPattern("yyyyMMdd"))
                + String.format("%04d", id);
    }
}
