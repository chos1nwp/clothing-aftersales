package com.example.aftersales.mapper;

import com.example.aftersales.entity.ActionLogDO;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface ActionLogMapper {

    int insert(ActionLogDO record);

    /**
     * @param consumerView true 时只返回对消费者可见的记录，用于隔离内部备注
     */
    List<ActionLogDO> findByAftersalesId(@Param("aftersalesId") long aftersalesId,
                                         @Param("consumerView") boolean consumerView);
}
