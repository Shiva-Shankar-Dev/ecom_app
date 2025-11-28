class Product {
  final String name, brand, description, deliveryTime, pid;
  final double price;
  final String category;
  final List<String> keywords;
  final List<String> images;
  final int stockQuantity;

  Product({
    required this.name,
    required this.brand,
    required this.images,
    required this.description,
    required this.category,
    required this.price,
    required this.deliveryTime,
    required this.pid,
    required this.keywords,
    required this.stockQuantity,
  });
}