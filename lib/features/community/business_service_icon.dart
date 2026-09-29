import 'package:flutter/material.dart';
import '../../domain/community_models.dart';

IconData businessServiceIcon(BusinessService service) => switch (service) {
  BusinessService.gardening => Icons.yard_outlined,
  BusinessService.pools => Icons.pool_outlined,
  BusinessService.concierge => Icons.home_repair_service_outlined,
  BusinessService.cleaning => Icons.cleaning_services_outlined,
  BusinessService.maintenance => Icons.handyman_outlined,
  BusinessService.construction => Icons.construction_outlined,
  BusinessService.food => Icons.restaurant_outlined,
  BusinessService.retail => Icons.storefront_outlined,
  BusinessService.health => Icons.health_and_safety_outlined,
  BusinessService.beauty => Icons.spa_outlined,
  BusinessService.transport => Icons.local_shipping_outlined,
  BusinessService.education => Icons.school_outlined,
  BusinessService.professionalServices => Icons.business_center_outlined,
  BusinessService.other => Icons.more_horiz,
};
