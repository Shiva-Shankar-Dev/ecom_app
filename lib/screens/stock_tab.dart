import 'package:flutter/material.dart';
import 'package:ecom_app/models/product.dart';

class StockTab extends StatelessWidget {
  final List<Product> products;

  const StockTab({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    // Get all variants from all products for individual display
    List<Map<String, dynamic>> allVariants = [];

    for (final product in products) {
      if (product.variants.isNotEmpty) {
        // Add each variant with product context
        for (final variant in product.variants) {
          allVariants.add({'product': product, 'variant': variant});
        }
      } else {
        // For products without variants, treat the product itself as a variant
        allVariants.add({
          'product': product,
          'variant': null, // No variant, use product data
        });
      }
    }

    return allVariants.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined, size: 100, color: Colors.grey),
                SizedBox(height: 20),
                Text(
                  'No Stock Available',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Add products to see stock information.',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          )
        : CustomScrollView(
            slivers: [
              SliverAppBar(
                surfaceTintColor: Colors.transparent,
                titleSpacing: 7,
                automaticallyImplyLeading: false,
                pinned: false,
                floating: true,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Stock Inventory',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Individual Variants (${allVariants.length} items)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(height: 10,),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = allVariants[index];
                    final product = item['product'] as Product;
                    final variant = item['variant'] as ProductVariant?;

                    return _buildStockVariantCard(product, variant);
                  },
                  childCount: allVariants.length,
                ),
              ),
            ],
          );
  }

  Widget _buildStockVariantCard(Product product, ProductVariant? variant) {
    // Determine stock quantity and other details
    final stockQuantity = variant?.stockQuantity ?? product.stockQuantity;
    final variantName = variant?.name ?? 'Base Product';
    final image = variant?.images.isNotEmpty == true
        ? variant!.images.first
        : null;

    // Determine stock status color
    Color stockColor;
    if (stockQuantity > 10) {
      stockColor = Colors.green;
    } else if (stockQuantity > 0) {
      stockColor = Colors.orange;
    } else {
      stockColor = Colors.red;
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // Product/Variant Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: image != null && image.isNotEmpty
                  ? Image.network(
                      image,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.image, color: Colors.grey[600]),
                      ),
                    )
                  : Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        color: Colors.blue[700],
                        size: 24,
                      ),
                    ),
            ),
            SizedBox(width: 16),

            // Product and Variant Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (variant != null && variantName != 'Base Product') ...[
                    SizedBox(height: 4),
                    Text(
                      variantName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Stock Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: stockColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: stockColor),
                  ),
                  child: Text(
                    '$stockQuantity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: stockColor,
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  stockQuantity == 0
                      ? 'Out of Stock'
                      : stockQuantity == 1
                      ? '1 left'
                      : 'in stock',
                  style: TextStyle(
                    fontSize: 12,
                    color: stockColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
