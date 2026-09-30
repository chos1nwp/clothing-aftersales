package com.example.aftersales.controller;

import com.example.aftersales.common.ApiResponse;
import com.example.aftersales.domain.LoginUser;
import com.example.aftersales.dto.LoginRequest;
import com.example.aftersales.service.AuthService;
import jakarta.servlet.http.HttpSession;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    public record UserView(long id, String username, String displayName, String role, String roleLabel) {

        static UserView of(LoginUser user) {
            return new UserView(user.id(), user.username(), user.displayName(),
                    user.role().name(), user.role().getLabel());
        }
    }

    @PostMapping("/login")
    public ApiResponse<UserView> login(@Valid @RequestBody LoginRequest request, HttpSession session) {
        LoginUser user = authService.login(request.getUsername(), request.getPassword(), session);
        return ApiResponse.ok(UserView.of(user));
    }

    @PostMapping("/logout")
    public ApiResponse<Void> logout(HttpSession session) {
        authService.logout(session);
        return ApiResponse.ok(null);
    }

    @GetMapping("/me")
    public ApiResponse<UserView> me(HttpSession session) {
        return ApiResponse.ok(UserView.of(authService.requireLogin(session)));
    }
}
