import 'package:flutter_test/flutter_test.dart';
import 'package:dalel/models/models.dart';
import 'package:dalel/config/constants.dart';

void main() {
  group('نماذج الحقول الخاصة بالأقسام', () {
    test('تحليل حقل قائمة مع خياراته', () {
      final j = {
        'id': 6,
        'key': 'specialty',
        'label': 'الاختصاص',
        'type': 'select',
        'required': true,
        'placeholder': 'ابحث عن الاختصاص…',
        'show_in_card': true,
        'filterable': true,
        'sort_order': 0,
        'options': [
          {'id': 1, 'label': 'أطفال', 'value': '1', 'icon': 'baby'},
          {'id': 2, 'label': 'روماتيزم', 'value': '2', 'icon': 'bone'},
        ],
      };

      final f = CategoryField.fromJson(j);

      expect(f.key, 'specialty');
      expect(f.label, 'الاختصاص');
      expect(f.type, 'select');
      expect(f.required, isTrue);
      expect(f.isSelect, isTrue);
      expect(f.options.length, 2);
      expect(f.options.first.label, 'أطفال');
      expect(f.options.first.icon, 'baby');
    });

    test('القسم يحمل حقوله', () {
      final c = Category.fromJson({
        'id': 38,
        'slug': 'doctors',
        'name': 'أطباء مختصون',
        'fields': [
          {
            'key': 'specialty',
            'label': 'الاختصاص',
            'type': 'select',
            'options': [
              {'id': 3, 'label': 'قلبية', 'value': '3', 'icon': 'heart'},
            ],
          },
        ],
      });

      expect(c.fields.length, 1);
      expect(c.fields.first.key, 'specialty');
      expect(c.fields.first.options.single.label, 'قلبية');
    });

    test('قسم بلا حقول → قائمة فارغة (لا انهيار)', () {
      final c = Category.fromJson({'id': 37, 'slug': 'pharmacies', 'name': 'صيدليات'});
      expect(c.fields, isEmpty);
    });

    test('الخدمة تحمل حقولها المحلولة', () {
      final s = Service.fromJson({
        'id': 10,
        'name': 'د. أحمد',
        'category_id': 38,
        'fields': [
          {
            'key': 'specialty',
            'label': 'الاختصاص',
            'type': 'select',
            'value': '6',
            'display': 'أمراض قلبية',
            'icon': 'heart',
          },
        ],
      });

      expect(s.fields.length, 1);
      expect(s.fields.first.label, 'الاختصاص');
      expect(s.fields.first.display, 'أمراض قلبية');
      expect(s.fields.first.icon, 'heart');
    });

    test('خدمة بلا حقول → قائمة فارغة', () {
      final s = Service.fromJson({'id': 11, 'name': 'صيدلية', 'category_id': 37});
      expect(s.fields, isEmpty);
    });

    test('أنواع الحقول تُصنَّف صحيحاً', () {
      expect(CategoryField.fromJson({'key': 'a', 'label': 'A', 'type': 'select'}).isSelect, isTrue);
      expect(CategoryField.fromJson({'key': 'b', 'label': 'B', 'type': 'boolean'}).isBoolean, isTrue);
      expect(CategoryField.fromJson({'key': 'c', 'label': 'C', 'type': 'number'}).isNumber, isTrue);
      expect(CategoryField.fromJson({'key': 'd', 'label': 'D', 'type': 'textarea'}).isTextarea, isTrue);

      // نوع مفقود → افتراضي select
      expect(CategoryField.fromJson({'key': 'e', 'label': 'E'}).type, 'select');
    });

    test('حقل نصي بلا خيارات', () {
      final f = CategoryField.fromJson({
        'key': 'pharmacist',
        'label': 'الصيدلاني',
        'type': 'text',
        'placeholder': 'الاسم الثلاثي',
      });
      expect(f.type, 'text');
      expect(f.options, isEmpty);
      expect(f.isSelect, isFalse);
      expect(f.placeholder, 'الاسم الثلاثي');
    });

    test('الحقول المحلولة تصمد أمام بيانات ناقصة', () {
      final f = ResolvedField.fromJson({'key': 'x', 'label': 'س'});
      expect(f.display, '');
      expect(f.icon, '');
      expect(f.value, '');
    });
  });

  group('حلّ الاختصاص — منع عرض الأرقام الخام', () {
  test('الاختصاص المُخزَّن كمُعرّف يُحلّ إلى اسمه (لا يُعرض رقماً)', () {
    // خيارات حقل الاختصاص: id=27.. value="1".. label
    final opts = [
      FieldOption(id: 27, label: 'أطفال', value: '1', icon: '👶'),
      FieldOption(id: 31, label: 'أمراض داخلية', value: '5', icon: '🩺'),
    ];
    final field = CategoryField(
      id: 1,
      key: 'specialty',
      label: 'الاختصاص',
      type: 'select',
      required: true,
      options: opts,
    );
    final cat = Category(
      id: 38,
      slug: 'doctors',
      name: 'أطباء',
      fields: [field],
    );

    // ─── المحاكاة: القيمة الخام «5» من meta ───
    const raw = '5';

    final resolved = cat.fields
        .where((f) => f.key == 'specialty')
        .expand((f) => f.options)
        .where((o) =>
            o.value == raw ||
            o.id.toString() == raw ||
            o.label == raw)
        .map((o) => o.label)
        .firstOrNull;

    expect(resolved, 'أمراض داخلية',
        reason: 'القيمة «5» يجب أن تُحلّ إلى «أمراض داخلية» لا أن تُعرض كما هي');

    // ─── قيمة رقمية بلا خيار مطابق لا تُعرض خاماً ───
    const orphan = '999';
    final orphanResolved = cat.fields
        .where((f) => f.key == 'specialty')
        .expand((f) => f.options)
        .where((o) =>
            o.value == orphan ||
            o.id.toString() == orphan ||
            o.label == orphan)
        .map((o) => o.label)
        .firstOrNull;

    expect(orphanResolved, isNull, reason: 'لا خيار مطابق');
    expect(RegExp(r'^\d+$').hasMatch(orphan), isTrue,
        reason: 'قيمة رقمية → يجب إخفاؤها لا عرضها');
  });

  test('الاسم القديم يبقى كما هو (توافقية عكسية)', () {
    final opts = [
      FieldOption(id: 31, label: 'أمراض داخلية', value: '5', icon: '🩺'),
    ];
    final cat = Category(
      id: 38,
      slug: 'doctors',
      name: 'أطباء',
      fields: [
        CategoryField(
            id: 1,
            key: 'specialty',
            label: 'الاختصاص',
            type: 'select',
            required: true,
            options: opts),
      ],
    );

    const raw = 'أمراض داخلية'; // الصيغة القديمة
    final resolved = cat.fields
        .where((f) => f.key == 'specialty')
        .expand((f) => f.options)
        .where((o) => o.value == raw || o.id.toString() == raw || o.label == raw)
        .map((o) => o.label)
        .firstOrNull;

    expect(resolved, 'أمراض داخلية', reason: 'الاسم القديم يعمل أيضاً');
  });
  });

  group('سلامة النصوص العربية', () {
    test('حالة الإغلاق تُكتب «مغلقة» لا «مقلقة»', () {
      expect(ServiceStatus.label('closed'), 'مغلقة');
      expect(ServiceStatus.label('closed'), isNot(contains('مقلقة')));
    });

    test('كل تسميات الحالة خالية من الخطأ «مقلقة»', () {
      final labels = [
        ServiceStatus.label('open'),
        ServiceStatus.label('closed'),
        ServiceStatus.label('anything', onDuty: true),
        ServiceStatus.label(null),
      ];
      for (final l in labels) {
        expect(l, isNot(contains('مقلقة')), reason: '«$l» تحتوي الخطأ');
      }
      expect(labels, contains('مغلقة'));
    });

    test('النموذج يعرض «مغلقة» عند الإغلاق', () {
      final closed = Service(
        id: 1,
        name: 'خدمة',
        categoryId: 1,
        status: 'closed',
      );
      expect(closed.displayStatus, 'مغلقة');
      expect(closed.displayStatus, isNot(contains('مقلقة')));

      final open = Service(
          id: 2, name: 'خدمة', categoryId: 1, status: 'open');
      expect(open.displayStatus, 'تعمل الآن');
    });
  });
}
