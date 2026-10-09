import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:flutter/material.dart';
import '../../domain/community_models.dart';

IconData businessServiceIcon(BusinessService service) => switch (service) {
  BusinessService.gardening => WicchuIcons.plant,
  BusinessService.pools => WicchuIcons.swimmingPool,
  BusinessService.concierge => WicchuIcons.briefcase,
  BusinessService.cleaning => WicchuIcons.broom,
  BusinessService.maintenance => WicchuIcons.hammer,
  BusinessService.construction => WicchuIcons.hammer,
  BusinessService.food => WicchuIcons.forkKnife,
  BusinessService.retail => WicchuIcons.storefront,
  BusinessService.health => WicchuIcons.shieldPlus,
  BusinessService.beauty => WicchuIcons.leaf,
  BusinessService.transport => WicchuIcons.truck,
  BusinessService.education => WicchuIcons.graduationCap,
  BusinessService.professionalServices => WicchuIcons.briefcase,
  BusinessService.realEstate => WicchuIcons.buildings,
  BusinessService.other => WicchuIcons.dotsThree,
};
