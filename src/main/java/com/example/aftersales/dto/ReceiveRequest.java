package com.example.aftersales.dto;

import jakarta.validation.constraints.NotBlank;

public record ReceiveRequest(
        @NotBlank(message = "请填写实际收到的包裹号")
        String parcelNo
) {
}
