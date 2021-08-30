-- About PrimoNewUI.lua
--
-- Author: Bill Jones III, SUNY Geneseo, IDS Project, jonesw@geneseo.edu
-- PrimoNewUI.lua provides a basic search for ISBN, ISSN, Title, and Phrase Searching for the Primo New UI interface.
-- There is a config file that is associated with this Addon that needs to be set up in order for the Addon to work.
-- Please see the ReadMe.txt file for example configuration values that you can pull from your Primo New UI URL.
--
-- IMPORTANT:  One of the following settings must be set to true in order for the Addon to work:
-- set GoToLandingPage to true for this script to automatically navigate to your instance of Primo New UI.
-- set AutoSearchISxN to true if you would like the Addon to automatically search for the ISxN.
-- set AutoSearchTitle to true if you would like the Addon to automatically search for the Title.
--
-- Modified 2020-02-11 by Tamara Marnell, Central Oregon Community College, libsys@cocc.edu

local settings = {};
settings.GoToLandingPage = GetSetting("GoToLandingPage");
settings.AutoSearchISxN = GetSetting("AutoSearchISxN");
settings.AutoSearchTitle = GetSetting("AutoSearchTitle");
settings.PrimoVE = GetSetting("PrimoVE");
settings.BaseURL = GetSetting("BaseURL");
settings.DatabaseName = GetSetting("DatabaseName");
settings.SearchTab = GetSetting("SearchTab");
settings.SearchScope = GetSetting("SearchScope");

local params = "tab=" .. settings.SearchTab .. "&search_scope=" .. settings.SearchScope .. "&vid=" .. settings.DatabaseName .. "&sortby=rank&offset=0";

local interfaceMngr = nil;
local PrimoNewUIForm = {};
PrimoNewUIForm.Form = nil;
PrimoNewUIForm.Browser = nil;
PrimoNewUIForm.RibbonPage = nil;

function Init()
  -- The line below makes this Addon work on all request types.
  if GetFieldValue("Transaction", "RequestType") ~= "" then
    interfaceMngr = GetInterfaceManager();

    -- Create browser
    PrimoNewUIForm.Form = interfaceMngr:CreateForm("PrimoNewUI", "Script");
    PrimoNewUIForm.Browser = PrimoNewUIForm.Form:CreateBrowser("PrimoNewUI", "PrimoNewUI", "PrimoNewUI");

    -- Hide the text label
    PrimoNewUIForm.Browser.TextVisible = false;

    --Suppress Javascript errors
    PrimoNewUIForm.Browser.WebBrowser.ScriptErrorsSuppressed = true;

    -- Since we didn't create a ribbon explicitly before creating our browser, it will have created one using the name we passed the CreateBrowser method. We can retrieve that one and add our buttons to it.
    PrimoNewUIForm.RibbonPage = PrimoNewUIForm.Form:GetRibbonPage("PrimoNewUI");
    -- The GetClientImage("Search32") pulls in the magnifying glass icon. There are other icons that can be used.
    -- Here we are adding a new button to the ribbon
    PrimoNewUIForm.RibbonPage:CreateButton("Search ISxN", GetClientImage("Search32"), "SearchISxN", "PrimoNewUI");
    PrimoNewUIForm.RibbonPage:CreateButton("Search Title", GetClientImage("Search32"), "SearchTitle", "PrimoNewUI");
    PrimoNewUIForm.RibbonPage:CreateButton("Phrase Search", GetClientImage("Search32"), "SearchPhrase", "PrimoNewUI");
    
    if settings.PrimoVE then
      -- For customers on Primo VE, add one button mapped to function InputLocationVE
      PrimoNewUIForm.RibbonPage:CreateButton("Input Location/ Call Number", GetClientImage("Borrowing32"), "InputLocationVE", "Location Info");
    else
      -- For customers not on Primo VE, add two buttons: one to open the mashup source, and a second to import location and call number
      PrimoNewUIForm.RibbonPage:CreateButton("Open Holdings", GetClientImage("Borrowing32"), "OpenMashupSource", "Location Info");
      PrimoNewUIForm.RibbonPage:CreateButton("Input Location/ Call Number", GetClientImage("Borrowing32"), "InputLocation", "Location Info");
    end

    PrimoNewUIForm.Form:Show();
  end
  if settings.GoToLandingPage then
    DefaultURL();
  elseif settings.AutoSearchISxN then
    SearchISxN();
  elseif settings.AutoSearchTitle then
    SearchTitle();
  end
end

function DefaultURL()
  PrimoNewUIForm.Browser:Navigate(settings.BaseURL .. "?vid=" .. settings.DatabaseName);
end

-- This function searches for ISxN for both Loan and Article requests.
function SearchISxN()
  if GetFieldValue("Transaction", "ISSN") ~= "" then
  local issn = GetFieldValue("Transaction", "ISSN");
  local stripped_issn = issn:gsub('%D','');
    PrimoNewUIForm.Browser:Navigate(settings.BaseURL .. "?query=any,contains," .. stripped_issn .. "&" .. params);
  else
    interfaceMngr:ShowMessage("ISxN is not available from request form", "Insufficient Information");
  end
end

-- This function performs a quoted phrase search for LoanTitle for Loan requests and PhotoJournalTitle for Article requests.
function SearchPhrase()
  if GetFieldValue("Transaction", "RequestType") == "Loan" then  
    PrimoNewUIForm.Browser:Navigate(settings.BaseURL .. "?query=any,contains,%22" .. GetFieldValue("Transaction", "LoanTitle")  .. "%22&"  .. params);
  elseif GetFieldValue("Transaction", "RequestType") == "Article" then  
    PrimoNewUIForm.Browser:Navigate(settings.BaseURL .. "?query=any,contains,%22" .. GetFieldValue("Transaction", "PhotoJournalTitle")  .. "%22&"  .. params);
  else
    interfaceMngr:ShowMessage("The Title is not available from request form", "Insufficient Information");
  end
end

-- This function performs a standard search for LoanTitle for Loan requests and PhotoJournalTitle for Article requests.
function SearchTitle()
  if GetFieldValue("Transaction", "RequestType") == "Loan" then  
    PrimoNewUIForm.Browser:Navigate(settings.BaseURL .. "?query=any,contains," ..  GetFieldValue("Transaction", "LoanTitle") .. "&" .. params);
  elseif GetFieldValue("Transaction", "RequestType") == "Article" then  
    PrimoNewUIForm.Browser:Navigate(settings.BaseURL .. "?query=any,contains," .. GetFieldValue("Transaction", "PhotoJournalTitle") .. "&" .. params);
  else
    interfaceMngr:ShowMessage("The Title is not available from request form", "Insufficient Information");
  end
end

-- This function opens the Alma mashup iframe source
function OpenMashupSource()
  local document = PrimoNewUIForm.Browser.WebBrowser.Document;
  -- If selectIssueForm exists, this is the mashup window. Prompt user to click the input button instead.
  if document:getElementById('selectIssueForm') ~= nil then
    interfaceMngr:ShowMessage("Select a holding and click the Input Location/Call Number button.", "Holdings open");
    return false;
  else
	-- If mashup component doesn't exist, prompt user to open a full record.
	local mashups = document:GetElementsByTagName("prm-alma-mashup");
	if (mashups.count == 0) then
      interfaceMngr:ShowMessage("Open a full record.", "Record not selected");
      return false;
    else
      -- Loop through the iframes in the mashup component. If one is the AlmagetitMashupIframe, navigate to the source.
	  local mashup = mashups:get_Item(0);
      local iframes = mashup:getElementsByTagName("iframe");
      local iframe = nil;
      for i=0,iframes.count-1 do
        iframe = iframes:get_Item(i);
        if iframe.Name == "AlmagetitMashupIframe" then
          PrimoNewUIForm.Browser:Navigate(iframe:GetAttribute("src"));
          break
        end
      end
    end
  end
end

-- This function populates the call number and location in the detail form with the values from the Alma mashup window for customers not on Primo VE
function InputLocation()
  local document = PrimoNewUIForm.Browser.WebBrowser.Document;
  -- If selectIssueForm does not exist, this is the search results page. Prompt user to open holdings in the mashup window first.
  if document:getElementById("selectIssueForm") == nil then
    interfaceMngr:ShowMessage("Open a full record and click the Open Holdings button.", "Open holdings first");
    return false;
  else
    -- If the Location label does not exist, the mashup is showing multiple holdings.
    -- Prompt user to select one first.
    if document:GetElementById("locationLabel") == nil then
      interfaceMngr:ShowMessage("Select a holding to import.", "Multiple holdings found");
      return false;
    else
      -- Loop through all spans on the page. Get info from spans with classes "itemLocationName" and "itemAccessionNumber."
      local spans = document:GetElementsByTagName("span");
      local span = nil;
      local span_class = nil;
      local location_name = nil;
      local call_number = nil;
      for s=0,spans.count-1 do
        span = spans:get_Item(s);
        span_class = span:GetAttribute("className");
        if span_class ~= nil then
          if span_class == "itemLocationName" then
            location_name = span.InnerText;  
          elseif span_class == "itemAccessionNumber" then
            call_number = span.InnerText;
          end
        end
      end
      if (location_name == nil or call_number == nil) then
        interfaceMngr:ShowMessage("Location or call number not found on this page.", "Information not found");
        return false;
      else
        SetFieldValue("Transaction", "Location", location_name);
        SetFieldValue("Transaction", "CallNumber", call_number);
      end
    end
  end
  -- Switch back to Details form.
  ExecuteCommand("SwitchTab", {"Detail"});
end

-- This function populates the call number and location in the detail form for Ex Libris customers on Primo VE
function InputLocationVE()
  local document = PrimoNewUIForm.Browser.WebBrowser.Document;
  -- If the OPAC component does not exist, prompt user to open a full record with local availability
  local opacs = document:GetElementsByTagName("prm-opac");
  if opacs.count == 0 then
    interfaceMngr:ShowMessage("Open a full record with local items available.", "Record with physical holdings required");
  return false;
  else
    -- Get items within the OPAC component (not other members)
    local opac = opacs:get_Item(0);
    local lis = opac:getElementsByTagName("prm-location-items");
    if lis.count == 0 then
      interfaceMngr:ShowMessage("No local items found in this record.", "Items not found");
      return false;
    else
	  -- Loop through all spans and get info based on ng-if and ng-bind-html attributes (no classes or useful IDs in VE)
      local location_items = lis:get_Item(0);
      local spans = location_items:getElementsByTagName("span");
      local span = nil;
      local span_if = nil;
      local span_bind = nil;
      local location_name = nil;
      local call_number = nil;
      for s=0,spans.count-1 do
  	    span = spans:get_Item(s);
        span_bind = span:GetAttribute("ng-bind-html");
		span_if = span:GetAttribute("ng-if");
        if span_bind ~= nil then
          if string.find(span_bind, "collectionTranslation") then
            location_name = span.innerText;
          end
        end
		if span_if ~= nil then
          if string.find(span_if, "callNumber") then
            if span.innerText ~= "" then
              call_number = span.innerText;
            end
          end
        end
      end
      if (location_name == nil or call_number == nil) then
        interfaceMngr:ShowMessage("Location or call number not found on this page.", "Information not found");
        return false;
      else
        SetFieldValue("Transaction", "Location", location_name);
        SetFieldValue("Transaction", "CallNumber", call_number);
      end
    end
  end
  -- Switch back to Details form.
  ExecuteCommand("SwitchTab", {"Detail"});
end
