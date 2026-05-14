import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../features/wardrobe/domain/wardrobe_item_model.dart';
import '../../features/wardrobe/presentation/pages/wardrobe_item_detail_page.dart';

class WardrobeItemCard extends StatelessWidget {
  final WardrobeItem item;

  const WardrobeItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WardrobeItemDetailPage(item: item),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen contenedora
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                imageBuilder: (context, imageProvider) => Container(
                  width: double.infinity,

                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Textos
          Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "${item.brand ?? 'No brand'} • ${item.category}",
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
