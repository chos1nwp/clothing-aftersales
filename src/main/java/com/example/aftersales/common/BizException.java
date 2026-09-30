package com.example.aftersales.common;

/**
 * 业务异常：httpStatus 400 参数或规则不满足，403 无权限，409 状态冲突。
 */
public class BizException extends RuntimeException {

    private final int httpStatus;

    public BizException(int httpStatus, String message) {
        super(message);
        this.httpStatus = httpStatus;
    }

    public static BizException badRequest(String message) {
        return new BizException(400, message);
    }

    public static BizException forbidden(String message) {
        return new BizException(403, message);
    }

    public static BizException conflict(String message) {
        return new BizException(409, message);
    }

    public int getHttpStatus() {
        return httpStatus;
    }
}
