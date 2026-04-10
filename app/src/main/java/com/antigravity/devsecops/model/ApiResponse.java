package com.antigravity.devsecops.model;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Getter;

import java.time.Instant;

@Getter
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ApiResponse<T> {
    private final String  status;
    private final T       data;
    private final String  error;
    private final String  timestamp;

    private ApiResponse(String status, T data, String error) {
        this.status    = status;
        this.data      = data;
        this.error     = error;
        this.timestamp = Instant.now().toString();
    }

    public static <T> ApiResponse<T> success(T data) {
        return new ApiResponse<>("success", data, null);
    }

    public static <T> ApiResponse<T> error(String error) {
        return new ApiResponse<>("error", null, error);
    }
}
