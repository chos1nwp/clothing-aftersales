package com.example.aftersales.mapper;

import com.example.aftersales.domain.AftersalesStatus;
import com.example.aftersales.dto.AftersalesView;
import com.example.aftersales.dto.StatusCount;
import com.example.aftersales.entity.AftersalesOrderDO;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface AftersalesMapper {

    int insert(AftersalesOrderDO record);

    int updateAftersalesNo(@Param("id") long id, @Param("no") String no);

    AftersalesOrderDO findById(@Param("id") long id);

    AftersalesView findDetail(@Param("id") long id);

    List<AftersalesView> listByConsumer(@Param("userId") long userId, @Param("status") String status);

    List<AftersalesView> listForStaff(@Param("status") String status,
                                      @Param("type") String type,
                                      @Param("keyword") String keyword);

    List<StatusCount> countByStatus();

    /** 未被拒绝或取消的申请占用的数量 */
    int sumOccupiedQuantity(@Param("itemId") long itemId);

    /** 该订单商品上处于进行中（未关闭）的售后单数量 */
    int countOpenByItem(@Param("itemId") long itemId);

    /**
     * 带期望状态的更新（乐观并发）：返回 0 表示这张单已被其他操作改过，调用方应返回 409。
     */
    int updateState(@Param("a") AftersalesOrderDO record, @Param("expected") AftersalesStatus expected);
}
