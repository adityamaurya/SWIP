#!/usr/bin/env node
/**
 * Builds `assets/mcc/mcc_table.json`.
 *
 *   node tool/build_mcc_table.mjs
 *
 * ── On the publication field, and why it is mostly empty ───────────────────
 *
 * Ideation `D-05` asks the ledger to say whether a code is published
 * nationally, internationally, or by RuPay. That is exactly the right model and
 * the app implements all three. But the DATA has to be sourced, not invented:
 *
 *   international  Populated for every code below, from the ISO 18245 / Visa /
 *                  Mastercard published names. Safe.
 *   national       Populated only for codes in unambiguous domestic use in
 *                  India, listed in NATIONAL below.
 *   rupay          DELIBERATELY EMPTY IN v1. RuPay's category list is not
 *                  publicly available in a form I could verify, and a product
 *                  whose entire purpose is to stop people acting on wrong
 *                  category data must not ship invented category data. Ingest
 *                  it from the scheme, then set it here.
 *
 * See docs/03-RESEARCH §1 for why these three lists genuinely differ.
 */

import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const OUT = join(dirname(fileURLToPath(import.meta.url)), '../assets/mcc');

// code -> internationally published name (ISO 18245:2023 / Visa / Mastercard)
const CODES = {
  '0742': 'Veterinary Services',
  '1520': 'General Contractors — Residential and Commercial',
  '1711': 'Heating, Plumbing and Air Conditioning Contractors',
  '1731': 'Electrical Contractors',
  '1799': 'Special Trade Contractors',
  '2741': 'Miscellaneous Publishing and Printing',
  '4011': 'Railroads',
  '4111': 'Local and Suburban Commuter Passenger Transportation',
  '4112': 'Passenger Railways',
  '4119': 'Ambulance Services',
  '4121': 'Taxicabs and Limousines',
  '4131': 'Bus Lines',
  '4214': 'Motor Freight Carriers and Trucking',
  '4215': 'Courier Services',
  '4225': 'Public Warehousing and Storage',
  '4411': 'Steamship and Cruise Lines',
  '4457': 'Boat Rentals and Leases',
  '4511': 'Airlines and Air Carriers',
  '4582': 'Airports, Flying Fields and Airport Terminals',
  '4722': 'Travel Agencies and Tour Operators',
  '4784': 'Tolls and Bridge Fees',
  '4789': 'Transportation Services (Not Elsewhere Classified)',
  '4812': 'Telecommunication Equipment and Telephone Sales',
  '4814': 'Telecommunication Services',
  '4816': 'Computer Network / Information Services',
  '4821': 'Telegraph Services',
  '4829': 'Money Transfer',
  '4899': 'Cable, Satellite and Other Pay Television and Radio',
  '4900': 'Utilities — Electric, Gas, Water, Sanitary',
  '5013': 'Motor Vehicle Supplies and New Parts',
  '5039': 'Construction Materials',
  '5044': 'Photographic and Photocopy Equipment',
  '5045': 'Computers, Peripherals and Software',
  '5047': 'Medical, Dental and Hospital Equipment',
  '5065': 'Electrical Parts and Equipment',
  '5072': 'Hardware Equipment and Supplies',
  '5085': 'Industrial Supplies',
  '5111': 'Stationery, Office Supplies and Writing Paper',
  '5122': 'Drugs, Drug Proprietaries and Druggist Sundries',
  '5131': 'Piece Goods, Notions and Other Dry Goods',
  '5169': 'Chemicals and Allied Products',
  '5172': 'Petroleum and Petroleum Products',
  '5192': 'Books, Periodicals and Newspapers',
  '5193': "Florists' Supplies, Nursery Stock and Flowers",
  '5198': 'Paints, Varnishes and Supplies',
  '5199': 'Nondurable Goods',
  '5200': 'Home Supply Warehouse Stores',
  '5211': 'Lumber and Building Materials Stores',
  '5231': 'Glass, Paint and Wallpaper Stores',
  '5251': 'Hardware Stores',
  '5261': 'Nurseries, Lawn and Garden Supply Stores',
  '5300': 'Wholesale Clubs',
  '5309': 'Duty Free Stores',
  '5310': 'Discount Stores',
  '5311': 'Department Stores',
  '5331': 'Variety Stores',
  '5399': 'Miscellaneous General Merchandise',
  '5411': 'Grocery Stores and Supermarkets',
  '5441': 'Candy, Nut and Confectionery Stores',
  '5451': 'Dairy Products Stores',
  '5462': 'Bakeries',
  '5499': 'Miscellaneous Food Stores — Convenience and Specialty',
  '5511': 'Car and Truck Dealers — Sales and Service',
  '5532': 'Automotive Tire Stores',
  '5533': 'Automotive Parts and Accessories Stores',
  '5541': 'Service Stations',
  '5542': 'Automated Fuel Dispensers',
  '5571': 'Motorcycle Shops and Dealers',
  '5599': 'Miscellaneous Automotive and Farm Equipment Dealers',
  '5611': "Men's and Boys' Clothing and Accessories Stores",
  '5621': "Women's Ready-to-Wear Stores",
  '5631': "Women's Accessory and Specialty Shops",
  '5641': "Children's and Infants' Wear Stores",
  '5651': 'Family Clothing Stores',
  '5655': 'Sports and Riding Apparel Stores',
  '5661': 'Shoe Stores',
  '5691': "Men's and Women's Clothing Stores",
  '5699': 'Miscellaneous Apparel and Accessory Shops',
  '5712': 'Furniture and Home Furnishings Stores',
  '5722': 'Household Appliance Stores',
  '5732': 'Electronics Stores',
  '5733': 'Music Stores — Instruments and Sheet Music',
  '5734': 'Computer Software Stores',
  '5811': 'Caterers',
  '5812': 'Eating Places and Restaurants',
  '5813': 'Drinking Places — Bars, Taverns, Nightclubs',
  '5814': 'Fast Food Restaurants',
  '5815': 'Digital Goods — Books, Movies, Music',
  '5816': 'Digital Goods — Games',
  '5817': 'Digital Goods — Applications (Excludes Games)',
  '5818': 'Digital Goods — Large Digital Goods Merchant',
  '5912': 'Drug Stores and Pharmacies',
  '5921': 'Package Stores — Beer, Wine and Liquor',
  '5931': 'Used Merchandise and Secondhand Stores',
  '5940': 'Bicycle Shops',
  '5941': 'Sporting Goods Stores',
  '5942': 'Book Stores',
  '5943': 'Stationery and Office Supply Stores',
  '5944': 'Jewellery, Watch and Silverware Stores',
  '5945': 'Hobby, Toy and Game Shops',
  '5946': 'Camera and Photographic Supply Stores',
  '5947': 'Gift, Card, Novelty and Souvenir Shops',
  '5948': 'Luggage and Leather Goods Stores',
  '5949': 'Sewing, Needlework and Fabric Stores',
  '5964': 'Direct Marketing — Catalog Merchant',
  '5965': 'Direct Marketing — Catalog and Retail Merchant',
  '5967': 'Direct Marketing — Inbound Teleservices',
  '5968': 'Direct Marketing — Continuity / Subscription',
  '5969': 'Direct Marketing — Other',
  '5970': "Artist's Supply and Craft Shops",
  '5977': 'Cosmetic Stores',
  '5983': 'Fuel Dealers',
  '5992': 'Florists',
  '5994': 'News Dealers and Newsstands',
  '5995': 'Pet Shops, Pet Food and Supplies',
  '5999': 'Miscellaneous and Specialty Retail Stores',
  '6010': 'Financial Institutions — Manual Cash Disbursements',
  '6011': 'Financial Institutions — Automated Cash Disbursements (ATM)',
  '6012': 'Financial Institutions — Merchandise and Services',
  '6051': 'Non-Financial Institutions — Foreign Currency, Money Orders, Quasi Cash',
  '6211': 'Security Brokers and Dealers',
  '6300': 'Insurance Sales, Underwriting and Premiums',
  '6381': 'Insurance Premiums',
  '6399': 'Insurance — Not Elsewhere Classified',
  '6513': 'Real Estate Agents and Managers — Rentals',
  '6540': 'Non-Financial Institutions — Stored Value Card Purchase / Load',
  '7011': 'Lodging — Hotels, Motels and Resorts',
  '7012': 'Timeshares',
  '7032': 'Sporting and Recreational Camps',
  '7210': 'Laundry, Cleaning and Garment Services',
  '7216': 'Dry Cleaners',
  '7221': 'Photographic Studios',
  '7230': 'Beauty and Barber Shops',
  '7273': 'Dating Services',
  '7276': 'Tax Preparation Services',
  '7298': 'Health and Beauty Spas',
  '7299': 'Miscellaneous Personal Services',
  '7311': 'Advertising Services',
  '7333': 'Commercial Photography, Art and Graphics',
  '7338': 'Quick Copy, Reproduction and Blueprinting',
  '7342': 'Exterminating and Disinfecting Services',
  '7349': 'Cleaning, Maintenance and Janitorial Services',
  '7361': 'Employment Agencies and Temporary Help',
  '7372': 'Computer Programming and Data Processing',
  '7375': 'Information Retrieval Services',
  '7379': 'Computer Maintenance and Repair',
  '7392': 'Management, Consulting and Public Relations',
  '7393': 'Detective, Protective and Security Services',
  '7399': 'Business Services — Not Elsewhere Classified',
  '7511': 'Truck Stop',
  '7512': 'Automobile Rental Agency',
  '7513': 'Truck and Utility Trailer Rentals',
  '7523': 'Parking Lots, Meters and Garages',
  '7531': 'Automotive Body Repair Shops',
  '7538': 'Automotive Service Shops',
  '7542': 'Car Washes',
  '7549': 'Towing Services',
  '7622': 'Electronics Repair Shops',
  '7629': 'Electrical and Small Appliance Repair',
  '7631': 'Watch, Clock and Jewellery Repair',
  '7699': 'Miscellaneous Repair Shops',
  '7829': 'Motion Picture and Video Tape Production',
  '7832': 'Motion Picture Theatres',
  '7841': 'Video Tape Rental Stores',
  '7911': 'Dance Halls, Studios and Schools',
  '7922': 'Theatrical Producers and Ticket Agencies',
  '7929': 'Bands, Orchestras and Miscellaneous Entertainers',
  '7932': 'Billiard and Pool Establishments',
  '7933': 'Bowling Alleys',
  '7941': 'Commercial Sports and Professional Sports Clubs',
  '7991': 'Tourist Attractions and Exhibits',
  '7992': 'Golf Courses — Public',
  '7994': 'Video Game Arcades and Establishments',
  '7995': 'Betting, Casino Gaming Chips and Lottery Tickets',
  '7996': 'Amusement Parks, Carnivals and Circuses',
  '7997': 'Membership Clubs, Country Clubs and Private Golf Courses',
  '7998': 'Aquariums, Seaquariums and Zoos',
  '7999': 'Recreation Services — Not Elsewhere Classified',
  '8011': 'Doctors and Physicians',
  '8021': 'Dentists and Orthodontists',
  '8041': 'Chiropractors',
  '8042': 'Optometrists and Ophthalmologists',
  '8043': 'Opticians, Optical Goods and Eyeglasses',
  '8050': 'Nursing and Personal Care Facilities',
  '8062': 'Hospitals',
  '8071': 'Medical and Dental Laboratories',
  '8099': 'Medical Services and Health Practitioners',
  '8111': 'Legal Services and Attorneys',
  '8211': 'Elementary and Secondary Schools',
  '8220': 'Colleges, Universities and Professional Schools',
  '8241': 'Correspondence Schools',
  '8244': 'Business and Secretarial Schools',
  '8249': 'Vocational and Trade Schools',
  '8299': 'Schools and Educational Services',
  '8351': 'Child Care Services',
  '8398': 'Charitable and Social Service Organisations',
  '8641': 'Civic, Social and Fraternal Associations',
  '8651': 'Political Organisations',
  '8661': 'Religious Organisations',
  '8675': 'Automobile Associations',
  '8699': 'Membership Organisations',
  '8734': 'Testing Laboratories',
  '8911': 'Architectural, Engineering and Surveying Services',
  '8931': 'Accounting, Auditing and Bookkeeping Services',
  '8999': 'Professional Services',
  '9211': 'Court Costs, Including Alimony and Child Support',
  '9222': 'Fines',
  '9223': 'Bail and Bond Payments',
  '9311': 'Tax Payments',
  '9399': 'Government Services',
  '9402': 'Postal Services — Government Only',
  '9405': 'Intra-Government Purchases',
};

/**
 * Codes in unambiguous domestic use in India, so they also carry a `national`
 * publication. Conservative on purpose — a code marked national that is not
 * would be exactly the kind of confidently-wrong data this product exists to
 * eliminate.
 */
const NATIONAL = new Set([
  '4111', '4121', '4131', '4214', '4215', '4511', '4722', '4784', '4814',
  '4816', '4829', '4899', '4900', '5122', '5192', '5311', '5411', '5462',
  '5499', '5541', '5542', '5651', '5732', '5812', '5813', '5814', '5912',
  '5941', '5942', '5944', '5999', '6011', '6051', '6300', '6513', '6540',
  '7011', '7230', '7298', '7299', '7311', '7372', '7512', '7523', '7832',
  '7995', '8011', '8062', '8099', '8211', '8220', '8299', '8398', '9311',
]);

const codes = Object.entries(CODES)
  .sort(([a], [b]) => a.localeCompare(b))
  .map(([code, name]) => {
    const definitions = [{ publication: 'international', name }];
    if (NATIONAL.has(code)) definitions.push({ publication: 'national', name });
    // publication: 'rupay' — intentionally unpopulated. See the header.
    return { code, definitions };
  });

const payload = {
  $schema: 'https://swip.in/schema/mcc-table-1.json',
  version: 1,
  generatedAt: new Date().toISOString().slice(0, 10),
  source: 'ISO 18245:2023 ranges; Visa / Mastercard published category names',
  caveats: [
    'rupay publications are not populated in v1 — the list was not verifiable.',
    'Networks publish overlapping but non-identical lists; Mastercard alone carries ~879 codes.',
    'This is a curated working set, not the complete table.',
  ],
  codes,
};

mkdirSync(OUT, { recursive: true });
writeFileSync(join(OUT, 'mcc_table.json'), JSON.stringify(payload, null, 1));
console.log(`wrote assets/mcc/mcc_table.json — ${codes.length} codes`);
