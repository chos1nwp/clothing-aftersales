package com.example.aftersales.mapper;

import com.example.aftersales.entity.AppUserDO;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface AppUserMapper {

    AppUserDO findByUsername(@Param("username") String username);

    AppUserDO findById(@Param("id") long id);

    List<AppUserDO> findAll();
}
