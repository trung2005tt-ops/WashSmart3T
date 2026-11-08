/// Danh mục loại đồ, dịch vụ và đơn vị tính ban đầu cho WashSmart 3T.
/// Nguồn danh mục: tài liệu "Các loại đồ.docx" do người dùng cung cấp.
/// Đây là dữ liệu giao diện ban đầu; khi tích hợp API, nên chuyển danh mục
/// dịch vụ/đơn giá sang backend để tránh hard-code giá trong ứng dụng.

class LaundryClothingType {
  final String group;
  final String name;
  final List<String> suggestedUnits;

  const LaundryClothingType({
    required this.group,
    required this.name,
    required this.suggestedUnits,
  });
}

class LaundryServiceOption {
  final String name;
  final List<String> applicableClothingTypes;
  final List<String> units;

  const LaundryServiceOption({
    required this.name,
    required this.applicableClothingTypes,
    required this.units,
  });
}

class LaundryCatalog {
  LaundryCatalog._();

  static const List<String> units = <String>[
    'Kg',
    'Cái',
    'Đôi',
    'Bộ',
    'Món',
    'Con',
    'M²',
  ];

  static const List<LaundryClothingType> clothingTypes = <LaundryClothingType>[
    LaundryClothingType(
      group: 'Đồ cá nhân',
      name: 'Áo thun',
      suggestedUnits: ['Kg', 'Cái'],
    ),
    LaundryClothingType(
      group: 'Đồ cá nhân',
      name: 'Áo sơ mi',
      suggestedUnits: ['Kg', 'Cái'],
    ),
    LaundryClothingType(
      group: 'Đồ cá nhân',
      name: 'Quần jean',
      suggestedUnits: ['Kg', 'Cái'],
    ),
    LaundryClothingType(
      group: 'Đồ cá nhân',
      name: 'Quần tây',
      suggestedUnits: ['Kg', 'Cái'],
    ),
    LaundryClothingType(
      group: 'Đồ cá nhân',
      name: 'Quần short',
      suggestedUnits: ['Kg', 'Cái'],
    ),
    LaundryClothingType(
      group: 'Đồ cá nhân',
      name: 'Áo khoác',
      suggestedUnits: ['Kg', 'Cái'],
    ),
    LaundryClothingType(
      group: 'Đồ cá nhân',
      name: 'Áo len',
      suggestedUnits: ['Kg', 'Cái'],
    ),
    LaundryClothingType(
      group: 'Trang phục công sở, cao cấp',
      name: 'Áo vest',
      suggestedUnits: ['Bộ', 'Cái', 'Món'],
    ),
    LaundryClothingType(
      group: 'Trang phục công sở, cao cấp',
      name: 'Quần âu',
      suggestedUnits: ['Cái', 'Kg'],
    ),
    LaundryClothingType(
      group: 'Trang phục công sở, cao cấp',
      name: 'Áo ghi lê',
      suggestedUnits: ['Cái', 'Món'],
    ),
    LaundryClothingType(
      group: 'Trang phục công sở, cao cấp',
      name: 'Đầm',
      suggestedUnits: ['Cái', 'Món'],
    ),
    LaundryClothingType(
      group: 'Trang phục công sở, cao cấp',
      name: 'Váy',
      suggestedUnits: ['Cái', 'Món'],
    ),
    LaundryClothingType(
      group: 'Trang phục công sở, cao cấp',
      name: 'Áo dài',
      suggestedUnits: ['Bộ', 'Món'],
    ),
    LaundryClothingType(
      group: 'Trang phục công sở, cao cấp',
      name: 'Váy cưới',
      suggestedUnits: ['Bộ', 'Món'],
    ),
    LaundryClothingType(
      group: 'Đồ em bé và đồ nhạy cảm',
      name: 'Quần áo trẻ sơ sinh',
      suggestedUnits: ['Kg', 'Cái'],
    ),
    LaundryClothingType(
      group: 'Đồ em bé và đồ nhạy cảm',
      name: 'Đồ lót',
      suggestedUnits: ['Kg', 'Cái'],
    ),
    LaundryClothingType(
      group: 'Đồ em bé và đồ nhạy cảm',
      name: 'Tất',
      suggestedUnits: ['Kg', 'Đôi'],
    ),
    LaundryClothingType(
      group: 'Đồ gia dụng và đồ vải',
      name: 'Chăn',
      suggestedUnits: ['Kg', 'Cái', 'Bộ'],
    ),
    LaundryClothingType(
      group: 'Đồ gia dụng và đồ vải',
      name: 'Ga giường',
      suggestedUnits: ['Kg', 'Cái', 'Bộ'],
    ),
    LaundryClothingType(
      group: 'Đồ gia dụng và đồ vải',
      name: 'Gối',
      suggestedUnits: ['Cái', 'Kg'],
    ),
    LaundryClothingType(
      group: 'Đồ gia dụng và đồ vải',
      name: 'Mền',
      suggestedUnits: ['Kg', 'Cái', 'Bộ'],
    ),
    LaundryClothingType(
      group: 'Đồ gia dụng và đồ vải',
      name: 'Khăn tắm',
      suggestedUnits: ['Kg', 'Cái'],
    ),
    LaundryClothingType(
      group: 'Đồ gia dụng và đồ vải',
      name: 'Khăn trải bàn',
      suggestedUnits: ['Kg', 'Cái'],
    ),
    LaundryClothingType(
      group: 'Đồ gia dụng và đồ vải',
      name: 'Khăn phủ ghế',
      suggestedUnits: ['Kg', 'Cái'],
    ),
    LaundryClothingType(
      group: 'Rèm cửa và thảm',
      name: 'Rèm cửa',
      suggestedUnits: ['Kg', 'M²'],
    ),
    LaundryClothingType(
      group: 'Rèm cửa và thảm',
      name: 'Thảm',
      suggestedUnits: ['Kg', 'M²'],
    ),
    LaundryClothingType(
      group: 'Giày dép',
      name: 'Giày thể thao',
      suggestedUnits: ['Đôi'],
    ),
    LaundryClothingType(
      group: 'Giày dép',
      name: 'Sneaker',
      suggestedUnits: ['Đôi'],
    ),
    LaundryClothingType(
      group: 'Giày dép',
      name: 'Giày da',
      suggestedUnits: ['Đôi'],
    ),
    LaundryClothingType(
      group: 'Giày dép',
      name: 'Dép',
      suggestedUnits: ['Đôi'],
    ),
    LaundryClothingType(
      group: 'Túi xách và vật dụng khác',
      name: 'Balo',
      suggestedUnits: ['Cái', 'Món'],
    ),
    LaundryClothingType(
      group: 'Túi xách và vật dụng khác',
      name: 'Túi xách',
      suggestedUnits: ['Cái', 'Món'],
    ),
    LaundryClothingType(
      group: 'Túi xách và vật dụng khác',
      name: 'Vali',
      suggestedUnits: ['Cái', 'Món'],
    ),
    LaundryClothingType(
      group: 'Túi xách và vật dụng khác',
      name: 'Gấu bông',
      suggestedUnits: ['Con', 'Cái'],
    ),
    LaundryClothingType(
      group: 'Túi xách và vật dụng khác',
      name: 'Thú nhồi bông',
      suggestedUnits: ['Con', 'Cái'],
    ),
    LaundryClothingType(
      group: 'Túi xách và vật dụng khác',
      name: 'Nón bảo hiểm',
      suggestedUnits: ['Cái', 'Món'],
    ),
    LaundryClothingType(
      group: 'Nệm',
      name: 'Topper',
      suggestedUnits: ['M²', 'Cái'],
    ),
    LaundryClothingType(
      group: 'Nệm',
      name: 'Nệm',
      suggestedUnits: ['M²', 'Cái'],
    ),
  ];

  static const List<LaundryServiceOption> services = <LaundryServiceOption>[
    LaundryServiceOption(
      name: 'Giặt sấy thường',
      applicableClothingTypes: [
        'Áo thun',
        'Áo sơ mi',
        'Quần jean',
        'Quần tây',
        'Quần short',
        'Áo khoác',
        'Áo len',
        'Quần áo trẻ sơ sinh',
        'Đồ lót',
        'Tất',
        'Khăn tắm',
        'Khăn trải bàn',
        'Khăn phủ ghế',
        'Đồng phục',
        'Đồ ngủ',
      ],
      units: ['Kg', 'Cái', 'Bộ'],
    ),
    LaundryServiceOption(
      name: 'Giặt sấy nhanh',
      applicableClothingTypes: [
        'Áo thun',
        'Áo sơ mi',
        'Quần jean',
        'Quần tây',
        'Quần short',
        'Áo khoác',
        'Áo len',
        'Đồ ngủ',
      ],
      units: ['Kg', 'Cái', 'Bộ'],
    ),
    LaundryServiceOption(
      name: 'Giặt riêng đồ trắng',
      applicableClothingTypes: [
        'Áo thun',
        'Áo sơ mi',
        'Quần jean',
        'Quần tây',
        'Quần short',
        'Quần áo trẻ sơ sinh',
      ],
      units: ['Kg', 'Cái'],
    ),
    LaundryServiceOption(
      name: 'Giặt hấp/giặt khô',
      applicableClothingTypes: [
        'Áo vest',
        'Quần âu',
        'Áo ghi lê',
        'Đầm',
        'Váy',
        'Áo dài',
        'Váy cưới',
      ],
      units: ['Món', 'Cái', 'Bộ'],
    ),
    LaundryServiceOption(
      name: 'Ủi/là quần áo',
      applicableClothingTypes: ['Áo sơ mi', 'Quần tây', 'Váy', 'Áo dài'],
      units: ['Cái', 'Bộ', 'Món'],
    ),
    LaundryServiceOption(
      name: 'Giặt chăn mền',
      applicableClothingTypes: ['Chăn', 'Mền'],
      units: ['Kg', 'Cái', 'Bộ'],
    ),
    LaundryServiceOption(
      name: 'Giặt chăn ga gối',
      applicableClothingTypes: ['Ga giường', 'Gối', 'Chăn', 'Mền'],
      units: ['Kg', 'Cái', 'Bộ'],
    ),
    LaundryServiceOption(
      name: 'Giặt rèm cửa',
      applicableClothingTypes: ['Rèm cửa'],
      units: ['Kg', 'M²'],
    ),
    LaundryServiceOption(
      name: 'Vệ sinh giày dép',
      applicableClothingTypes: ['Giày thể thao', 'Sneaker', 'Giày da', 'Dép'],
      units: ['Đôi'],
    ),
    LaundryServiceOption(
      name: 'Vệ sinh túi xách, balo',
      applicableClothingTypes: ['Túi xách', 'Balo', 'Vali'],
      units: ['Cái', 'Món'],
    ),
    LaundryServiceOption(
      name: 'Giặt thú bông',
      applicableClothingTypes: ['Gấu bông', 'Thú nhồi bông'],
      units: ['Con', 'Cái'],
    ),
    LaundryServiceOption(
      name: 'Giặt thảm',
      applicableClothingTypes: ['Thảm'],
      units: ['M²', 'Kg'],
    ),
    LaundryServiceOption(
      name: 'Vệ sinh topper, nệm',
      applicableClothingTypes: ['Topper', 'Nệm'],
      units: ['M²', 'Cái'],
    ),
    LaundryServiceOption(
      name: 'Giặt đồng phục',
      applicableClothingTypes: [
        'Áo thun',
        'Áo sơ mi',
        'Quần tây',
        'Quần short',
      ],
      units: ['Kg', 'Cái', 'Bộ'],
    ),
    LaundryServiceOption(
      name: 'Giặt đồ ngủ',
      applicableClothingTypes: ['Áo thun', 'Quần short', 'Quần áo trẻ sơ sinh'],
      units: ['Kg', 'Cái'],
    ),
    LaundryServiceOption(
      name: 'Giặt hỏa tốc',
      applicableClothingTypes: [
        'Áo thun',
        'Áo sơ mi',
        'Quần jean',
        'Quần tây',
        'Quần short',
        'Áo khoác',
        'Áo len',
      ],
      units: ['Kg', 'Cái', 'Bộ', 'Món'],
    ),
  ];

  static List<LaundryClothingType> typesForGroup(String group) =>
      clothingTypes.where((item) => item.group == group).toList();

  static List<String> get groups =>
      clothingTypes.map((item) => item.group).toSet().toList();

  static List<LaundryServiceOption> servicesForType(String clothingType) =>
      services
          .where(
            (service) => service.applicableClothingTypes.contains(clothingType),
          )
          .toList();

  static List<String> unitsForTypeAndService(
    String clothingType,
    String serviceName,
  ) {
    final serviceMatches = services.where(
      (service) =>
          service.name == serviceName &&
          service.applicableClothingTypes.contains(clothingType),
    );
    if (serviceMatches.isNotEmpty) {
      final serviceUnits = serviceMatches.first.units;
      final typeUnits = clothingTypes
          .firstWhere((type) => type.name == clothingType)
          .suggestedUnits;
      final intersection = serviceUnits.where(typeUnits.contains).toList();
      if (intersection.isNotEmpty) return intersection;
      return serviceUnits;
    }
    return clothingTypes
        .firstWhere((type) => type.name == clothingType)
        .suggestedUnits;
  }
}
