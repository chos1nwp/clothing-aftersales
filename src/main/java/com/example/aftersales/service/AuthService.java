package com.example.aftersales.service;

import com.example.aftersales.common.BizException;
import com.example.aftersales.domain.LoginUser;
import com.example.aftersales.entity.AppUserDO;
import com.example.aftersales.mapper.AppUserMapper;
import com.example.aftersales.support.PasswordHasher;
import jakarta.servlet.http.HttpSession;
import org.springframework.stereotype.Service;

@Service
public class AuthService {

    public static final String SESSION_KEY = "LOGIN_USER";

    private final AppUserMapper userMapper;

    public AuthService(AppUserMapper userMapper) {
        this.userMapper = userMapper;
    }

    public LoginUser login(String username, String password, HttpSession session) {
        AppUserDO user = userMapper.findByUsername(username);
        if (user == null || !user.getPasswordHash().equals(PasswordHasher.hash(username, password))) {
            // 账号不存在与密码错误返回同一提示，避免账号枚举
            throw BizException.badRequest("账号或密码不正确");
        }
        LoginUser loginUser = new LoginUser(user.getId(), user.getUsername(),
                user.getDisplayName(), user.getRole());
        session.setAttribute(SESSION_KEY, loginUser);
        return loginUser;
    }

    public void logout(HttpSession session) {
        session.invalidate();
    }

    public LoginUser requireLogin(HttpSession session) {
        Object current = session.getAttribute(SESSION_KEY);
        if (current == null) {
            throw new BizException(401, "登录状态已失效，请重新登录");
        }
        return (LoginUser) current;
    }
}
