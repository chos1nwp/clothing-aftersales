package com.example.aftersales.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ResubmitRequest(
        @NotBlank(message = "请补充情况说明")
        @Size(min = 5, max = 500, message = "补充说明至少 5 个字")
        String description
) {
}
