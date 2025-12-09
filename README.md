# E-Commerce App with Product Variants

A Flutter-based e-commerce application with advanced product variant management system.

## Features

- **Product Management**: Upload and manage products via Excel files
- **Product Variants**: Support for multiple variants per product (colors, sizes, storage, etc.)
- **Inventory Tracking**: Track stock levels for each product and variant
- **Order Management**: View and manage customer orders with date-wise filtering
- **Bottom Navigation**: Easy navigation between Products, Stock, and Orders

## Product Variant System

The app supports a sophisticated variant system using a Parent ID approach with separate Excel sheets:

### Excel File Structure

Your Excel file should contain **two sheets**:

#### Sheet 1: "Products" (Parent Products)
| ID | Name | Brand | Category | Price | Description | Delivery Time | Stock Quantity | Images | Keywords |
|----|------|-------|----------|-------|-------------|---------------|----------------|--------|----------|
| P001 | iPhone 15 | Apple | Mobile | 79999 | Latest iPhone | 3-5 days | 50 | image1.jpg,image2.jpg | smartphone,ios,apple |
| P002 | Samsung TV | Samsung | TV | 45999 | 4K Smart TV | 5-7 days | 20 | tv1.jpg | television,4k,smart |

#### Sheet 2: "Variants" (Product Variants)
| Variant_ID | Parent_ID | Variant_Name | Price | Stock | Color | Storage | Size | Image |
|------------|-----------|--------------|-------|-------|-------|---------|------|-------|
| V001 | P001 | iPhone 15 Blue 128GB | 79999 | 15 | Blue | 128GB | | variant1.jpg |
| V002 | P001 | iPhone 15 Blue 256GB | 89999 | 12 | Blue | 256GB | | variant2.jpg |
| V003 | P001 | iPhone 15 Black 128GB | 79999 | 18 | Black | 128GB | | variant3.jpg |
| V004 | P002 | Samsung TV 32 inch | 35999 | 8 | Black | | 32 inch | tv32.jpg |
| V005 | P002 | Samsung TV 43 inch | 45999 | 12 | Black | | 43 inch | tv43.jpg |

### Key Fields

**Products Sheet:**
- `ID`: Unique product identifier (used as Parent_ID reference)
- `Name`: Product name
- `Price`: Base price (will be overridden by variant prices)
- Other standard product fields

**Variants Sheet:**
- `Variant_ID`: Unique variant identifier
- `Parent_ID`: References the ID from Products sheet
- `Variant_Name`: Display name for the variant
- `Price`: Variant-specific price
- `Stock`: Variant-specific stock quantity
- Custom attributes like `Color`, `Storage`, `Size`, etc.

### How It Works

1. **Upload**: Select your Excel file with both sheets
2. **Processing**: The app automatically links variants to their parent products using Parent_ID
3. **Display**: Products show with expandable variant details
4. **Pricing**: Products display price ranges based on variant prices
5. **Stock**: Each variant maintains its own stock level

## Getting Started

1. Prepare your Excel file with Products and Variants sheets
2. Run the app and navigate to the Products tab
3. Tap "Add Products" to upload your Excel file
4. View products with expandable variant details
5. Switch to Stock and Orders tabs for inventory and order management

## Dependencies

- Flutter SDK
- Firebase (Firestore, Auth, Storage)
- Excel processing
- File picker
- Lottie animations
