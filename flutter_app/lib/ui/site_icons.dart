import 'package:flutter/material.dart';

const siteIcons = <String, (IconData, String)>{
  'globe': (Icons.language, 'Web'),
  'envelope': (Icons.mail_outline, 'Correu'),
  'message': (Icons.chat_bubble_outline, 'Missatges'),
  'checklist': (Icons.checklist, 'Tasques'),
  'newspaper': (Icons.newspaper, 'Notícies'),
  'calendar': (Icons.calendar_month, 'Calendari'),
  'book': (Icons.menu_book, 'Lectura'),
  'star': (Icons.star_outline, 'Favorita'),
};
IconData siteIcon(String name) => siteIcons[name]?.$1 ?? Icons.language;
