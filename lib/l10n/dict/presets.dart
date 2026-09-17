// Стартовый набор категорий: имена, которые человек видит на экране.
//
// Ключи НЕ переименовывать: имя категории уезжает на сервер строкой и стоит в
// каждой операции. Смена ключа здесь — потеря связи траты со своей категорией.
const Map<String, Map<String, String>> presetStrings = {
  // ── расходы ──
  'catGroceries': {'ru': 'Продукты', 'en': 'Groceries'},
  'subSupermarket': {'ru': 'Супермаркет', 'en': 'Supermarket'},
  'subMarket': {'ru': 'Рынок', 'en': 'Market'},
  'subDelivery': {'ru': 'Доставка', 'en': 'Delivery'},

  'catEatingOut': {'ru': 'Кафе и рестораны', 'en': 'Eating out'},
  'subCoffee': {'ru': 'Кофе', 'en': 'Coffee'},
  'subLunch': {'ru': 'Обед', 'en': 'Lunch'},
  'subFoodDelivery': {'ru': 'Еда на дом', 'en': 'Food delivery'},

  'catTransport': {'ru': 'Транспорт', 'en': 'Transport'},
  'subTaxi': {'ru': 'Такси', 'en': 'Taxi'},
  'subFuel': {'ru': 'Топливо', 'en': 'Fuel'},
  'subTicket': {'ru': 'Проезд', 'en': 'Fares'},
  'subParking': {'ru': 'Парковка', 'en': 'Parking'},

  'catHousing': {'ru': 'Жильё', 'en': 'Housing'},
  'subRent': {'ru': 'Аренда', 'en': 'Rent'},
  'subUtilities': {'ru': 'Коммунальные', 'en': 'Utilities'},
  'subInternet': {'ru': 'Интернет', 'en': 'Internet'},
  'subRepair': {'ru': 'Ремонт', 'en': 'Repairs'},

  'catConnection': {'ru': 'Связь и подписки', 'en': 'Phone and subscriptions'},
  'subMobile': {'ru': 'Мобильная связь', 'en': 'Mobile'},
  'subSubscriptions': {'ru': 'Подписки', 'en': 'Subscriptions'},

  'catHealth': {'ru': 'Здоровье', 'en': 'Health'},
  'subPharmacy': {'ru': 'Аптека', 'en': 'Pharmacy'},
  'subDoctor': {'ru': 'Врач', 'en': 'Doctor'},
  'subTests': {'ru': 'Анализы', 'en': 'Lab tests'},

  'catBeauty': {'ru': 'Красота', 'en': 'Beauty'},
  'subHair': {'ru': 'Парикмахерская', 'en': 'Hairdresser'},
  'subCosmetics': {'ru': 'Косметика', 'en': 'Cosmetics'},

  'catClothes': {'ru': 'Одежда', 'en': 'Clothes'},
  'subClothes': {'ru': 'Вещи', 'en': 'Garments'},
  'subShoes': {'ru': 'Обувь', 'en': 'Shoes'},

  'catFun': {'ru': 'Развлечения', 'en': 'Fun'},
  'subCinema': {'ru': 'Кино', 'en': 'Cinema'},
  'subGames': {'ru': 'Игры', 'en': 'Games'},
  'subBooks': {'ru': 'Книги', 'en': 'Books'},

  'catSport': {'ru': 'Спорт', 'en': 'Sport'},
  'subGym': {'ru': 'Зал', 'en': 'Gym'},
  'subGear': {'ru': 'Инвентарь', 'en': 'Gear'},

  'catEducation': {'ru': 'Образование', 'en': 'Education'},
  'subCourses': {'ru': 'Курсы', 'en': 'Courses'},
  'subTextbooks': {'ru': 'Учебники', 'en': 'Textbooks'},

  'catTravel': {'ru': 'Путешествия', 'en': 'Travel'},
  'subTickets': {'ru': 'Билеты', 'en': 'Tickets'},
  'subStay': {'ru': 'Жильё в поездке', 'en': 'Stay'},

  'catGifts': {'ru': 'Подарки', 'en': 'Gifts'},
  'catPets': {'ru': 'Питомцы', 'en': 'Pets'},
  'subPetFood': {'ru': 'Корм', 'en': 'Pet food'},
  'subVet': {'ru': 'Ветеринар', 'en': 'Vet'},

  'catKids': {'ru': 'Дети', 'en': 'Kids'},
  'catSavings': {'ru': 'Откладываю', 'en': 'Set aside'},
  'catOther': {'ru': 'Прочее', 'en': 'Other'},

  // ── доходы ──
  'catSalary': {'ru': 'Зарплата', 'en': 'Salary'},
  'catAdvance': {'ru': 'Аванс', 'en': 'Advance'},
  'catSideJob': {'ru': 'Подработка', 'en': 'Side job'},
  'catFreelance': {'ru': 'Фриланс', 'en': 'Freelance'},
  'catInterest': {'ru': 'Проценты', 'en': 'Interest'},
  'catRefund': {'ru': 'Возврат', 'en': 'Refund'},
  'catGiftIn': {'ru': 'Подарок', 'en': 'Gift'},
  'catSale': {'ru': 'Продажа', 'en': 'Sale'},
  'catOtherIn': {'ru': 'Прочий доход', 'en': 'Other income'},
};
