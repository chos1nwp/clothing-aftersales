package com.example.aftersales.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 客服最终结论：FINAL_EXCHANGE / FINAL_REFUND / FINAL_REJECT。
 * 退款金额由服务端按订单商品单价计算，不接受前端传入。
 */
public record FinalizeRequest(
        @NotBlank(message = "请选择处理结论")
        String action,

        String trackingNo,

        String note
) {
}
