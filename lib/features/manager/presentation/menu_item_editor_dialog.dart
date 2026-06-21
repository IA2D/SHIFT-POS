// ignore_for_file: require_trailing_commas

import 'package:flutter/material.dart';

import '../../../app/app_state_scope.dart';
import '../../inventory/domain/ingredient.dart';
import '../../menu/domain/menu_category.dart';
import '../../menu/domain/menu_item.dart';
import '../../printers/domain/kitchen_printer.dart';

Future<void> showMenuItemEditorDialog(
  BuildContext context, {
  required List<MenuCategory> categories,
  required List<ItemSize> sizes,
  required List<ItemAddon> addons,
  required List<Ingredient> ingredients,
  required List<KitchenPrinter> kitchenPrinters,
  required Future<void> Function() onSaved,
  MenuItem? item,
  Recipe? recipe,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _MenuItemEditorDialog(
      categories: categories,
      sizes: sizes,
      addons: addons,
      ingredients: ingredients,
      kitchenPrinters: kitchenPrinters,
      item: item,
      recipe: recipe,
      onSaved: onSaved,
    ),
  );
}

class _MenuItemEditorDialog extends StatefulWidget {
  const _MenuItemEditorDialog({
    required this.categories,
    required this.sizes,
    required this.addons,
    required this.ingredients,
    required this.kitchenPrinters,
    required this.onSaved,
    this.item,
    this.recipe,
  });

  final List<MenuCategory> categories;
  final List<ItemSize> sizes;
  final List<ItemAddon> addons;
  final List<Ingredient> ingredients;
  final List<KitchenPrinter> kitchenPrinters;
  final MenuItem? item;
  final Recipe? recipe;
  final Future<void> Function() onSaved;

  @override
  State<_MenuItemEditorDialog> createState() => _MenuItemEditorDialogState();
}

class _MenuItemEditorDialogState extends State<_MenuItemEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _customWeightPrice;
  late String _categoryId;
  late MenuItemType _itemType;
  late ProductType _productType;
  late String? _linkedIngredientId;
  late bool _weighted;
  late bool _allowCustomWeight;
  late bool _active;
  late final Map<String, TextEditingController> _sizePrices;
  late final Map<String, TextEditingController> _addonPrices;
  late final List<_WeightedDraft> _weightedOptions;
  late final List<_RecipeLineDraft> _recipeLines;
  late final Set<String> _printerIds;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.nameAr ?? '');
    _description = TextEditingController(text: item?.descriptionAr ?? '');
    _price = TextEditingController(
      text: item == null ? '' : item.price.toStringAsFixed(2),
    );
    _customWeightPrice = TextEditingController(
      text: item?.customWeightUnitPrice?.toStringAsFixed(2) ?? '',
    );
    _categoryId = item?.categoryId ?? widget.categories.first.id;
    _itemType = item?.itemType ?? MenuItemType.product;
    _productType = item?.productType ?? ProductType.recipe;
    _linkedIngredientId = item?.linkedIngredientId;
    _weighted = item?.isWeighted ?? false;
    _allowCustomWeight = item?.allowCustomWeight ?? false;
    _active = item?.active ?? true;
    _sizePrices = {
      for (final option in item?.sizeOptions ?? const <MenuItemSizeOption>[])
        if (option.masterSizeId != null)
          option.masterSizeId!: TextEditingController(
            text: option.price.toStringAsFixed(2),
          ),
    };
    _addonPrices = {
      for (final option in item?.attachments ?? const <MenuItemAttachment>[])
        if (option.masterAddonId != null)
          option.masterAddonId!: TextEditingController(
            text: option.price.toStringAsFixed(2),
          ),
    };
    _weightedOptions = (item?.weightedPriceOptions ?? const [])
        .map(_WeightedDraft.fromOption)
        .toList();
    if (_weightedOptions.isEmpty) {
      _weightedOptions.add(_WeightedDraft.kilogram());
    }
    _recipeLines = (widget.recipe?.lines ?? const [])
        .map(_RecipeLineDraft.fromLine)
        .toList();
    if (_recipeLines.isEmpty) _recipeLines.add(_RecipeLineDraft());
    _printerIds = {...?item?.kitchenPrinterIds};
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _customWeightPrice.dispose();
    for (final controller in _sizePrices.values) {
      controller.dispose();
    }
    for (final controller in _addonPrices.values) {
      controller.dispose();
    }
    for (final option in _weightedOptions) {
      option.dispose();
    }
    for (final line in _recipeLines) {
      line.dispose();
    }
    super.dispose();
  }

  bool get _needsRecipe =>
      _itemType == MenuItemType.product && _productType == ProductType.recipe;

  bool get _needsLinkedStock =>
      _itemType == MenuItemType.rawMaterial ||
      (_itemType == MenuItemType.product &&
          (_productType == ProductType.readyMade ||
              _productType == ProductType.manufactured));

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'اسم الصنف مطلوب.');
      return;
    }
    final weightedOptions = _weighted
        ? _weightedOptions
            .map((draft) => draft.toOption())
            .whereType<WeightedPriceOption>()
            .toList()
        : <WeightedPriceOption>[];
    if (_weighted && weightedOptions.isEmpty) {
      setState(() => _error = 'أضف سعراً واحداً على الأقل لمنتج الميزان.');
      return;
    }
    final customPrice = double.tryParse(_customWeightPrice.text.trim());
    if (_weighted && _allowCustomWeight && customPrice == null) {
      setState(() => _error = 'سعر الكيلو للوزن المخصص مطلوب.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = AppStateScope.of(context).menuRepository;
      final now = DateTime.now();
      final id = widget.item?.id ?? 'item-${now.microsecondsSinceEpoch}';
      final recipeId = widget.item?.recipeId.isNotEmpty == true
          ? widget.item!.recipeId
          : 'recipe-$id';
      final sizeOptions = widget.sizes
          .where((size) => _sizePrices.containsKey(size.id))
          .map(
            (size) => MenuItemSizeOption(
              id: 'size-$id-${size.id}',
              masterSizeId: size.id,
              labelAr: size.nameAr,
              price: double.tryParse(_sizePrices[size.id]!.text.trim()) ?? 0,
            ),
          )
          .toList();
      final attachments = widget.addons
          .where((addon) => _addonPrices.containsKey(addon.id))
          .map(
            (addon) => MenuItemAttachment(
              id: 'addon-$id-${addon.id}',
              masterAddonId: addon.id,
              nameAr: addon.nameAr,
              price: double.tryParse(_addonPrices[addon.id]!.text.trim()) ??
                  addon.defaultPrice,
            ),
          )
          .toList();
      final unitPrice = _weighted
          ? customPrice ??
              weightedOptions.first.price / weightedOptions.first.weightKg
          : double.tryParse(_price.text.trim()) ?? 0;
      await repository.saveItem(
        MenuItem(
          id: id,
          categoryId: _categoryId,
          nameAr: name,
          descriptionAr: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          price: unitPrice,
          itemType: _itemType,
          productType: _productType,
          linkedIngredientId: _needsLinkedStock ? _linkedIngredientId : null,
          sizeOptions: _weighted ? const [] : sizeOptions,
          attachments:
              _itemType == MenuItemType.rawMaterial ? const [] : attachments,
          isWeighted: _itemType == MenuItemType.product && _weighted,
          weightedPriceOptions: weightedOptions,
          allowCustomWeight: _weighted && _allowCustomWeight,
          customWeightUnitPrice:
              _weighted && _allowCustomWeight ? customPrice : null,
          kitchenPrinterIds: _printerIds.toList(),
          imageUrl: widget.item?.imageUrl,
          active: _active,
          recipeId: recipeId,
          sortOrder: widget.item?.sortOrder ?? 0,
          createdAt: widget.item?.createdAt ?? now,
          updatedAt: now,
        ),
      );
      if (_needsRecipe) {
        final lines = _recipeLines
            .map((draft) => draft.toLine(widget.ingredients))
            .whereType<RecipeLine>()
            .toList();
        await repository.saveRecipe(
          Recipe(
            id: recipeId,
            menuItemId: id,
            nameAr: 'وصفة $name',
            basisQuantity: _weighted ? 1 : null,
            basisUnit: _weighted ? 'كجم' : null,
            lines: lines,
          ),
        );
      }
      await widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'إضافة صنف' : 'تعديل صنف'),
      content: SizedBox(
        width: 860,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _field(_name, 'اسم الصنف', 250),
                  _categoryField(),
                  _itemTypeField(),
                  if (_itemType == MenuItemType.product) _productTypeField(),
                  if (!_weighted) _field(_price, 'السعر', 150, number: true),
                  if (_needsLinkedStock) _ingredientField(),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'الوصف'),
                maxLines: 2,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                title: const Text('الصنف مفعل'),
                onChanged: (value) => setState(() => _active = value),
              ),
              if (_itemType == MenuItemType.product)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _weighted,
                  title: const Text('منتج ميزان'),
                  subtitle: const Text('الوصفة والأسعار محسوبة بالكيلوجرام'),
                  onChanged: (value) => setState(() => _weighted = value),
                ),
              if (_weighted) _weightedEditor(),
              if (!_weighted && _itemType != MenuItemType.rawMaterial)
                _optionEditor(
                  title: 'الأحجام',
                  children: widget.sizes
                      .where((size) => size.active)
                      .map(
                        (size) => _pricedOption(
                          id: size.id,
                          label: size.nameAr,
                          prices: _sizePrices,
                          defaultPrice: 0,
                        ),
                      )
                      .toList(),
                ),
              if (_itemType != MenuItemType.rawMaterial)
                _optionEditor(
                  title: 'الإضافات',
                  children: widget.addons
                      .where((addon) => addon.active)
                      .map(
                        (addon) => _pricedOption(
                          id: addon.id,
                          label: addon.nameAr,
                          prices: _addonPrices,
                          defaultPrice: addon.defaultPrice,
                        ),
                      )
                      .toList(),
                ),
              if (widget.kitchenPrinters.isNotEmpty)
                _optionEditor(
                  title: 'طابعات التجهيز',
                  children: widget.kitchenPrinters
                      .where((printer) => printer.active)
                      .map(
                        (printer) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _printerIds.contains(printer.id),
                          title: Text(printer.name),
                          subtitle: Text(printer.deviceName),
                          onChanged: (selected) => setState(() {
                            if (selected == true) {
                              _printerIds.add(printer.id);
                            } else {
                              _printerIds.remove(printer.id);
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),
              if (_needsRecipe) _recipeEditor(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('حفظ الصنف'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    double width, {
    bool number = false,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _categoryField() => SizedBox(
        width: 210,
        child: DropdownButtonFormField<String>(
          initialValue: _categoryId,
          decoration: const InputDecoration(labelText: 'التصنيف'),
          items: widget.categories
              .where((category) => category.active)
              .map((category) => DropdownMenuItem(
                    value: category.id,
                    child: Text(category.nameAr),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _categoryId = value!),
        ),
      );

  Widget _itemTypeField() => SizedBox(
        width: 180,
        child: DropdownButtonFormField<MenuItemType>(
          initialValue: _itemType,
          decoration: const InputDecoration(labelText: 'نوع الصنف'),
          items: MenuItemType.values
              .map((value) => DropdownMenuItem(
                    value: value,
                    child: Text(_itemTypeLabel(value)),
                  ))
              .toList(),
          onChanged: (value) => setState(() {
            _itemType = value!;
            if (_itemType != MenuItemType.product) _weighted = false;
          }),
        ),
      );

  Widget _productTypeField() => SizedBox(
        width: 230,
        child: DropdownButtonFormField<ProductType>(
          initialValue: _productType,
          decoration: const InputDecoration(labelText: 'نوع المنتج'),
          items: ProductType.values
              .map((value) => DropdownMenuItem(
                    value: value,
                    child: Text(_productTypeLabel(value)),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _productType = value!),
        ),
      );

  Widget _ingredientField() => SizedBox(
        width: 220,
        child: DropdownButtonFormField<String?>(
          initialValue: _linkedIngredientId,
          decoration: const InputDecoration(labelText: 'رصيد المخزون المرتبط'),
          items: [
            const DropdownMenuItem<String?>(
                value: null, child: Text('بدون ربط')),
            ...widget.ingredients.where((value) => value.active).map(
                  (value) => DropdownMenuItem<String?>(
                    value: value.id,
                    child: Text('${value.nameAr} (${value.unit})'),
                  ),
                ),
          ],
          onChanged: (value) => setState(() => _linkedIngredientId = value),
        ),
      );

  Widget _weightedEditor() {
    return _optionEditor(
      title: 'أسعار الميزان',
      children: [
        for (var index = 0; index < _weightedOptions.length; index++)
          Row(
            key: ValueKey(_weightedOptions[index].id),
            children: [
              Expanded(
                  child: _field(_weightedOptions[index].label, 'اسم الزر',
                      double.infinity)),
              const SizedBox(width: 8),
              SizedBox(
                  width: 120,
                  child: _field(_weightedOptions[index].grams, 'جرام', 120,
                      number: true)),
              const SizedBox(width: 8),
              SizedBox(
                  width: 130,
                  child: _field(_weightedOptions[index].price, 'السعر', 130,
                      number: true)),
              IconButton(
                tooltip: 'حذف السعر',
                onPressed: _weightedOptions.length == 1
                    ? null
                    : () => setState(() {
                          _weightedOptions.removeAt(index).dispose();
                        }),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () =>
                setState(() => _weightedOptions.add(_WeightedDraft())),
            icon: const Icon(Icons.add),
            label: const Text('سعر ميزان'),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _allowCustomWeight,
          title: const Text('السماح بوزن مخصص'),
          onChanged: (value) => setState(() => _allowCustomWeight = value),
        ),
        if (_allowCustomWeight)
          _field(_customWeightPrice, 'سعر الكيلو للوزن المخصص', 260,
              number: true),
      ],
    );
  }

  Widget _optionEditor(
      {required String title, required List<Widget> children}) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      children: children,
    );
  }

  Widget _pricedOption({
    required String id,
    required String label,
    required Map<String, TextEditingController> prices,
    required double defaultPrice,
  }) {
    final selected = prices.containsKey(id);
    return Row(
      children: [
        Checkbox(
          value: selected,
          onChanged: (value) => setState(() {
            if (value == true) {
              prices[id] = TextEditingController(
                text: defaultPrice.toStringAsFixed(2),
              );
            } else {
              prices.remove(id)?.dispose();
            }
          }),
        ),
        Expanded(child: Text(label)),
        if (selected) _field(prices[id]!, 'السعر', 140, number: true),
      ],
    );
  }

  Widget _recipeEditor() {
    return _optionEditor(
      title: 'مكونات الوصفة',
      children: [
        for (var index = 0; index < _recipeLines.length; index++)
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _recipeLines[index].ingredientId,
                  decoration: const InputDecoration(labelText: 'المكون'),
                  items: widget.ingredients
                      .where((ingredient) => ingredient.active)
                      .map((ingredient) => DropdownMenuItem<String?>(
                            value: ingredient.id,
                            child: Text(ingredient.nameAr),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() {
                    _recipeLines[index].ingredientId = value;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              _field(_recipeLines[index].quantity, 'الكمية', 120, number: true),
              const SizedBox(width: 8),
              Text(_recipeLines[index].unit(widget.ingredients)),
              IconButton(
                tooltip: 'حذف السطر',
                onPressed: _recipeLines.length == 1
                    ? null
                    : () => setState(() {
                          _recipeLines.removeAt(index).dispose();
                        }),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () =>
                setState(() => _recipeLines.add(_RecipeLineDraft())),
            icon: const Icon(Icons.add),
            label: const Text('سطر وصفة'),
          ),
        ),
      ],
    );
  }
}

class _WeightedDraft {
  _WeightedDraft({String label = '', String grams = '', String price = ''})
      : id = DateTime.now().microsecondsSinceEpoch.toString(),
        label = TextEditingController(text: label),
        grams = TextEditingController(text: grams),
        price = TextEditingController(text: price);

  factory _WeightedDraft.kilogram() =>
      _WeightedDraft(label: '1 كجم', grams: '1000');

  factory _WeightedDraft.fromOption(WeightedPriceOption option) =>
      _WeightedDraft(
        label: option.label,
        grams: (option.weightKg * 1000).toStringAsFixed(0),
        price: option.price.toStringAsFixed(2),
      );

  final String id;
  final TextEditingController label;
  final TextEditingController grams;
  final TextEditingController price;

  WeightedPriceOption? toOption() {
    final weightGrams = double.tryParse(grams.text.trim());
    final amount = double.tryParse(price.text.trim());
    if (label.text.trim().isEmpty ||
        weightGrams == null ||
        weightGrams <= 0 ||
        amount == null ||
        amount < 0) {
      return null;
    }
    return WeightedPriceOption(
      id: 'weight-$id',
      label: label.text.trim(),
      weightKg: weightGrams / 1000,
      price: amount,
    );
  }

  void dispose() {
    label.dispose();
    grams.dispose();
    price.dispose();
  }
}

class _RecipeLineDraft {
  _RecipeLineDraft({this.ingredientId, String quantity = ''})
      : quantity = TextEditingController(text: quantity);

  factory _RecipeLineDraft.fromLine(RecipeLine line) => _RecipeLineDraft(
        ingredientId: line.ingredientId,
        quantity: line.quantity.toString(),
      );

  String? ingredientId;
  final TextEditingController quantity;

  String unit(List<Ingredient> ingredients) {
    for (final ingredient in ingredients) {
      if (ingredient.id == ingredientId) return ingredient.unit;
    }
    return '';
  }

  RecipeLine? toLine(List<Ingredient> ingredients) {
    final id = ingredientId;
    final amount = double.tryParse(quantity.text.trim());
    if (id == null || amount == null || amount <= 0) return null;
    return RecipeLine(
      ingredientId: id,
      quantity: amount,
      unit: unit(ingredients),
    );
  }

  void dispose() => quantity.dispose();
}

String _itemTypeLabel(MenuItemType type) => switch (type) {
      MenuItemType.product => 'منتج',
      MenuItemType.rawMaterial => 'مادة خام',
      MenuItemType.service => 'خدمة',
    };

String _productTypeLabel(ProductType type) => switch (type) {
      ProductType.recipe => 'وصفة تحضر عند البيع',
      ProductType.readyMade => 'جاهز للبيع',
      ProductType.manufactured => 'مصنع مسبقاً',
      ProductType.noInventory => 'بدون مخزون',
    };
