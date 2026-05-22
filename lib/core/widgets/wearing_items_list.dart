import 'package:flutter/material.dart';
import 'app_network_image.dart';
import '../l10n/app_strings_es.dart';
import '../../../../core/utils/mock_data.dart';
import '../../../../features/wardrobe/domain/wardrobe_item_model.dart';

class WearingItemsList extends StatelessWidget {
  final List<String> itemIds;

  const WearingItemsList({super.key, required this.itemIds});

  @override
  Widget build(BuildContext context) {
    // En un caso real, buscaríamos estos items en la DB/Provider.
    // Aquí filtramos el MockData directamente para simplificar el MVP.
    final items = MockData.wardrobeItems
        .where((element) => itemIds.contains(element['id']))
        .map((e) => WardrobeItem.fromJson(e))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStringsEs.wearingThisLook,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton(
                onPressed: () {},
                child: Text(AppStringsEs.editItems),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: (0.05)),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: AppNetworkImage(
                            imageUrl: item.imageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item.brand ?? '',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
