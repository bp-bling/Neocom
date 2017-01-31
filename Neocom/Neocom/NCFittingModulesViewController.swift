//
//  NCFittingModulesViewController.swift
//  Neocom
//
//  Created by Artem Shimanski on 25.01.17.
//  Copyright © 2017 Artem Shimanski. All rights reserved.
//

import Foundation

class NCFittingModuleRow: TreeRow {
	lazy var type: NCDBInvType? = {
		return NCDatabase.sharedDatabase?.invTypes[self.module.typeID]
	}()
	lazy var chargeType: NCDBInvType? = {
		guard let charge = self.charge else {return nil}
		return NCDatabase.sharedDatabase?.invTypes[charge.typeID]
	}()
	
	let module: NCFittingModule
	let charge: NCFittingCharge?
	let slot: NCFittingModuleSlot
	let state: NCFittingModuleState
	let isEnabled: Bool
	let hasTarget: Bool
	
	init(module: NCFittingModule) {
		self.module = module
		self.charge = module.charge
		self.slot = module.slot
		self.state = module.state
		self.isEnabled = module.isEnabled
		self.hasTarget = module.target != nil
		needsUpdate = true
		super.init(cellIdentifier: module.isDummy ? "Cell" : "ModuleCell")
	}
	
	override func changed(from: TreeNode) -> Bool {
		guard let from = from as? NCFittingModuleRow else {return false}
		subtitle = from.subtitle
		return !module.isDummy
	}
	
	var needsUpdate: Bool
	var subtitle: NSAttributedString?
	
	override func configure(cell: UITableViewCell) {
		if module.isDummy {
			guard let cell = cell as? NCDefaultTableViewCell else {return}
			cell.object = module
			cell.iconView?.image = slot.image
			cell.titleLabel?.text = slot.title
		}
		else {
			guard let cell = cell as? NCFittingModuleTableViewCell else {return}
			cell.object = module
			cell.titleLabel?.text = type?.typeName
			cell.titleLabel?.textColor = isEnabled ? .white : .red
			cell.iconView?.image = type?.icon?.image?.image ?? NCDBEveIcon.defaultType.image?.image
			cell.stateView?.image = state.image
			cell.subtitleLabel?.attributedText = subtitle
			cell.targetIconView.image = hasTarget ? #imageLiteral(resourceName: "targets") : nil
			
			cell.subtitleLabel?.superview?.isHidden = subtitle == nil || subtitle?.length == 0
			
			if needsUpdate {
				let font = cell.subtitleLabel!.font!

				let module = self.module
				let chargeName = chargeType?.typeName
				let chargeImage = chargeType?.icon?.image?.image
				
				module.engine?.perform {
					guard let ship = module.owner as? NCFittingShip else {return}
					let string = NSMutableAttributedString()
					if let chargeName = chargeName  {
						var s = NSAttributedString(image: chargeImage, font: font) + " \(chargeName)"
						if module.charges > 0 {
							s = s + " x\(module.charges)" * [NSForegroundColorAttributeName: UIColor.caption]
						}
						string.appendLine(s)
					}
					let optimal = module.maxRange
					let falloff = module.falloff
					let angularVelocity = module.angularVelocity(targetSignature: ship.attributes[NCDBAttributeID.signatureRadius.rawValue]?.initialValue ?? 0)
					let accuracyScore = module.accuracyScore
					let lifeTime = module.lifeTime
					
					if optimal > 0 {
						let s: NSAttributedString
						let attr = [NSForegroundColorAttributeName: UIColor.caption]
						let image = NSAttributedString(image: #imageLiteral(resourceName: "targetingRange"), font: font)
						if falloff > 0 {
							s = image + " \(NSLocalizedString("optimal + falloff", comment: "")): " + (NCUnitFormatter.localizedString(from: optimal, unit: .meter, style: .full) + " + " + NCUnitFormatter.localizedString(from: falloff, unit: .meter, style: .full)) * attr
						}
						else {
							s =  image + "\(NSLocalizedString("optimal", comment: "")): " + NCUnitFormatter.localizedString(from: optimal, unit: .meter, style: .full) * attr
						}
						string.appendLine(s)
					}
					
					if accuracyScore > 0 {
						let v0 = ship.maxVelocity(orbit: optimal)
						let v1 = ship.maxVelocity(orbit: optimal + falloff)
						let orbitRadius = ship.orbitRadius(angularVelocity: angularVelocity)

						let color = angularVelocity * optimal > v0 ? UIColor.green : (angularVelocity * (optimal + falloff) > v1 ? UIColor.yellow : UIColor.red);
						let accuracy = NCUnitFormatter.localizedString(from: accuracyScore, unit: .none, style: .full) * [NSForegroundColorAttributeName: UIColor.caption]
						let range = NCUnitFormatter.localizedString(from: orbitRadius, unit: .custom(NSLocalizedString("+ m", comment: "meter"), false), style: .full) * [NSForegroundColorAttributeName: color]
						let s = NSAttributedString(image: #imageLiteral(resourceName: "tracking"), font: font) + " \(NSLocalizedString("accuracy", comment: "")): " + accuracy + " (" + NSAttributedString(image: #imageLiteral(resourceName: "targetingRange"), font: font) + " " + range + " )"
						
						string.appendLine(s)
					}
					
					if lifeTime > 0 {
						let s = NSAttributedString(image: #imageLiteral(resourceName: "overheated"), font: font) + " \(NSLocalizedString("lifetime", comment: "")): " + NCTimeIntervalFormatter.localizedString(from: lifeTime, precision: .seconds) * [NSForegroundColorAttributeName: UIColor.caption]
						string.appendLine(s)
					}
					
					DispatchQueue.main.async {
						self.needsUpdate = false
						self.subtitle = string
						guard let tableView = cell.tableView else {return}
						guard let indexPath = tableView.indexPath(for: cell) else {return}
						tableView.reloadRows(at: [indexPath], with: .fade)
					}
				}
			}
			else {
				cell.subtitleLabel?.attributedText = subtitle
			}
		}
	}
	
	override var hashValue: Int {
		return module.hashValue
	}
	
	override func isEqual(_ object: Any?) -> Bool {
		return (object as? NCFittingModuleRow)?.hashValue == hashValue
	}
	
}

class NCFittingModuleSection: TreeSection {
	let slot: NCFittingModuleSlot
	
	init(slot: NCFittingModuleSlot, children: [NCFittingModuleRow]) {
		self.slot = slot
		super.init(cellIdentifier: "HeaderCell")
		self.children = children
	}
	
	override var isExpandable: Bool {
		return false
	}
	
	override func configure(cell: UITableViewCell) {
		guard let cell = cell as? NCHeaderTableViewCell else {return}
		cell.iconView?.image = slot.image
		cell.titleLabel?.text = slot.title?.uppercased()
	}
	
	override var hashValue: Int {
		return slot.rawValue
	}
	
	override func isEqual(_ object: Any?) -> Bool {
		return (object as? NCFittingModuleSection)?.hashValue == hashValue
	}

}


class NCFittingModulesViewController: UIViewController, TreeControllerDelegate {
	@IBOutlet weak var treeController: TreeController!
	@IBOutlet weak var tableView: UITableView!

	@IBOutlet weak var powerGridLabel: NCResourceLabel!
	@IBOutlet weak var cpuLabel: NCResourceLabel!
	@IBOutlet weak var calibrationLabel: NCResourceLabel!
	@IBOutlet weak var turretsLabel: UILabel!
	@IBOutlet weak var launchersLabel: UILabel!
	
	var engine: NCFittingEngine? {
		return (parent as? NCShipFittingViewController)?.engine
	}
	
	var fleet: NCFleet? {
		return (parent as? NCShipFittingViewController)?.fleet
	}
	
	var typePickerViewController: NCTypePickerViewController? {
		return (parent as? NCShipFittingViewController)?.typePickerViewController
	}
	
	private var obsever: NSObjectProtocol?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		//treeController.childrenKeyPath = "children"
		tableView.estimatedRowHeight = tableView.rowHeight
		tableView.rowHeight = UITableViewAutomaticDimension
		treeController.delegate = self
		
		powerGridLabel.unit = .megaWatts
		cpuLabel.unit = .teraflops
		calibrationLabel.unit = .none
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		if self.treeController.rootNode == nil {
			engine?.perform {
				let sections = self.modulesSections
				DispatchQueue.main.async {
					self.treeController.rootNode = TreeNode()
					self.treeController.rootNode?.children = sections
				}
			}
			update()
		}
	
		if obsever == nil {
			obsever = NotificationCenter.default.addObserver(forName: .NCFittingEngineDidUpdate, object: engine, queue: nil) { [weak self] (note) in
				guard let strongSelf = self else {return}
				
				strongSelf.engine?.perform {
					let sections = strongSelf.modulesSections
					DispatchQueue.main.async {
						strongSelf.treeController.rootNode?.children = sections
					}
				}
				strongSelf.update()
			}
		}
	}
	
	//MARK: - TreeControllerDelegate
	
	func treeController(_ treeController: TreeController, didSelectCellWithNode node: TreeNode) {
		guard let item = node as? NCFittingModuleRow else {return}
		guard let pilot = fleet?.active else {return}
		//guard let ship = ship else {return}
		guard let typePickerViewController = typePickerViewController else {return}
		
		if item.module.isDummy {
			let category: NCDBDgmppItemCategory?
			switch item.slot {
			case .hi:
				category = NCDBDgmppItemCategory.category(categoryID: .hi, subcategory: NCDBCategoryID.module.rawValue)
			case .med:
				category = NCDBDgmppItemCategory.category(categoryID: .med, subcategory: NCDBCategoryID.module.rawValue)
			case .low:
				category = NCDBDgmppItemCategory.category(categoryID: .low, subcategory: NCDBCategoryID.module.rawValue)
//			case .rig:
//				category = NCDBDgmppItemCategory.category(categoryID: .rig, subcategory: ship.rigSize)
			//case .subsystem:
			//	category = NCDBDgmppItemCategory.category(categoryID: .subsystem, subcategory: ship.rigSize)
			default:
				return
			}
			typePickerViewController.category = category
			typePickerViewController.completionHandler = { [weak typePickerViewController] type in
				let typeID = Int(type.typeID)
				self.engine?.perform {
					_ = pilot.ship?.addModule(typeID: typeID)
				}
				typePickerViewController?.dismiss(animated: true)
			}
			present(typePickerViewController, animated: true)
		}
		else {
			performSegue(withIdentifier: "NCFittingModuleActionsViewController", sender: treeController.cell(for: node))
		}
	}
	
	//MARK: - Navigation
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		switch segue.identifier {
		case "NCFittingModuleActionsViewController"?:
			guard let controller = (segue.destination as? UINavigationController)?.topViewController as? NCFittingModuleActionsViewController else {return}
			guard let cell = sender as? NCFittingModuleTableViewCell else {return}
			controller.module = cell.object as? NCFittingModule
		default:
			break
		}
	}
	
	//MARK: - Private
	
	private var modulesSections: [NCFittingModuleSection] {
		guard let ship = fleet?.active?.ship else {return []}

		var sections = [NCFittingModuleSection]()
		for slot in [NCFittingModuleSlot.hi, NCFittingModuleSlot.med, NCFittingModuleSlot.low, NCFittingModuleSlot.rig, NCFittingModuleSlot.subsystem, NCFittingModuleSlot.service, NCFittingModuleSlot.mode] {
			let rows = ship.modules(slot: slot).flatMap({ (module) -> NCFittingModuleRow? in
				return NCFittingModuleRow(module: module)
			})
			if (rows.count > 0) {
				sections.append(NCFittingModuleSection(slot: slot, children: rows))
			}
		}
		return sections
	}
	
	private func update() {
		engine?.perform {
			guard let ship = self.fleet?.active?.ship else {return}
			let powerGridUsed = ship.powerGridUsed
			let totalPowerGrid = ship.totalPowerGrid
			let cpuUsed = ship.cpuUsed
			let totalCPU = ship.totalCPU
			let calibrationUsed = ship.calibrationUsed
			let totalCalibration = ship.totalCalibration
			
			let turrets = "\(ship.usedHardpoints(.turret))/\(ship.freeHardpoints(.turret))"
			let launchers = "\(ship.usedHardpoints(.launcher))/\(ship.freeHardpoints(.launcher))"
			DispatchQueue.main.async {
				self.powerGridLabel.value = powerGridUsed
				self.powerGridLabel.maximumValue = totalPowerGrid
				self.cpuLabel.value = cpuUsed
				self.cpuLabel.maximumValue = totalCPU
				self.calibrationLabel.value = calibrationUsed
				self.calibrationLabel.maximumValue = totalCalibration
				
				self.turretsLabel.text = turrets
				self.launchersLabel.text = launchers
			}
			
		}
	}
}
