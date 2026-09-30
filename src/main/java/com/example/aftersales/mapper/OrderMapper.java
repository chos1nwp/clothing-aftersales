package com.example.aftersales.mapper;

import com.example.aftersales.dto.ItemContext;
import com.example.aftersales.dto.OrderView;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface OrderMapper {

    /** 某消费者的全部订单及其商品，附带每个商品的可售后数量 */
    List<OrderView> findOrdersWithItems(@Param("userId") long userId);

    ItemContext findItemContext(@Param("itemId") long itemId);
}
